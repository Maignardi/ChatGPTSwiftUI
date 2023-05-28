import SwiftUI

struct Message: Identifiable {
    let id = UUID()
    let text: String
    let isUserMessage: Bool
}

class ChatViewModel: ObservableObject {
    @Published var messages = [Message]()
    @Published var isChatGPTTyping = false
    
    func sendMessage(_ message: String) {
        let newMessage = Message(text: message, isUserMessage: true)
        messages.append(newMessage)
        isChatGPTTyping = true
        
        let apiEndpoint = "https://api.openai.com/v1/chat/completions"
        let apiKey = "Aqui_Api_key"
        
        guard let url = URL(string: apiEndpoint) else {
            print("URL inválida")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let params: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "Você é um assistente útil."] as [String: String],
                ["role": "user", "content": message] as [String: String]
            ]
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: params) else {
            print("Falha ao converter os parâmetros em JSON")
            return
        }
        
        request.httpBody = httpBody
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Erro na chamada da API: \(error?.localizedDescription ?? "Erro desconhecido")")
                return
            }
            
            if let apiResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let choices = apiResponse["choices"] as? [[String: Any]],
               let assistantMessage = choices.first?["message"] as? [String: Any],
               let assistantReply = assistantMessage["content"] as? String {
                
                DispatchQueue.main.async {
                    let newAssistantMessage = Message(text: assistantReply, isUserMessage: false)
                    self.messages.append(newAssistantMessage)
                    self.isChatGPTTyping = false
                }
                
            } else {
                print("Resposta inválida da API")
            }
        }.resume()
    }
}

struct ContentView: View {
    @State private var newMessage = ""
    @State private var isKeyboardVisible = false
    @StateObject private var viewModel = ChatViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                Text("ChatGPT")
                    .padding()
                    .bold()
                ScrollView {
                    LazyVStack {
                        ForEach(viewModel.messages) { message in
                            Text(message.text)
                                .padding()
                                .background(message.isUserMessage ? Color.blue : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .padding(4)
                                .frame(maxWidth: .infinity, alignment: message.isUserMessage ? .trailing : .leading)
                        }
                        
                        if viewModel.isChatGPTTyping {
                            Text("ChatGPT está digitando...")
                                .italic()
                                .padding(.horizontal)
                        }
                    }
                }
                .onTapGesture {
                    endEditing()
                }
                
                HStack {
                    TextField("Digite uma mensagem", text: $newMessage)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: {
                        viewModel.sendMessage(newMessage)
                        newMessage = ""
                    }) {
                        Text("Enviar")
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
            .navigationTitle("")
            .onAppear {
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
                    isKeyboardVisible = true
                }
                
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                    isKeyboardVisible = false
                }
            }
        }
        .animation(.easeInOut)
    }
    
    private func endEditing() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
