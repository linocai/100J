import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isRegistering = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Image(systemName: "checklist.checked")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)
                Text("Personal Affairs")
                    .font(.largeTitle.weight(.semibold))
                Text("Sign in to your local v1 workspace")
                    .foregroundStyle(.secondary)
            }

            Form {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                if isRegistering {
                    TextField("Display name", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .formStyle(.grouped)
            .frame(width: 360)

            HStack {
                Button(isRegistering ? "Have an account?" : "Create account") {
                    isRegistering.toggle()
                }
                .buttonStyle(.link)

                Spacer()

                Button {
                    Task {
                        if isRegistering {
                            await model.register(email: email, password: password, displayName: displayName.trimmedOrNil)
                        } else {
                            await model.login(email: email, password: password)
                        }
                    }
                } label: {
                    if model.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(isRegistering ? "Register" : "Login")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || password.isEmpty || model.isLoading)
            }
            .frame(width: 360)
        }
        .padding(40)
    }
}
