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
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            #if os(macOS)
            .frame(width: 360)
            #else
            .frame(maxWidth: 420)
            .padding(.horizontal)
            #endif

            HStack {
                Button(isRegistering ? "Have an account?" : "Create account") {
                    isRegistering.toggle()
                }
                #if os(macOS)
                .buttonStyle(.link)
                #else
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                #endif

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
            #if os(macOS)
            .frame(width: 360)
            #else
            .frame(maxWidth: 420)
            .padding(.horizontal)
            #endif
        }
        #if os(macOS)
        .padding(40)
        #else
        .padding(.vertical, 28)
        #endif
    }
}
