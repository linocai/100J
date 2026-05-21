import AuthenticationServices
import SwiftUI

/// 包装 `SignInWithAppleButton` 并提供统一尺寸 / 占满父容器宽度。
struct AppleSignInButton: View {
    var maxWidth: CGFloat = 320
    var onCompletion: (Result<ASAuthorization, Error>) -> Void

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            onCompletion(result)
        }
        .signInWithAppleButtonStyle(buttonStyle)
        .frame(maxWidth: maxWidth)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var buttonStyle: SignInWithAppleButton.Style {
        #if os(iOS)
        return .black
        #else
        return .black
        #endif
    }
}
