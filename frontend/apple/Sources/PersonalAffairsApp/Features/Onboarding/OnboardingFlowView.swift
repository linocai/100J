import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("onboardingCompleted.v1.1") private var onboardingCompleted = false
    @State private var page = 0
    @State private var seedDemo = true
    @State private var isFinishing = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                OnboardingPageView(
                    systemImage: "sparkles",
                    title: "欢迎来到 100J",
                    subtitle: "把个人事务、公司事项、项目、笔记和日程收在同一个工作台里。"
                )
                .tag(0)

                OnboardingPageView(
                    systemImage: "person.2.badge.gearshape",
                    title: "数据按归属分层",
                    subtitle: "个人事项留在个人空间，公司任务和项目进入公司空间，后续同步与小组件也沿用同一条边界。"
                )
                .tag(1)

                VStack(spacing: 20) {
                    OnboardingPageView(
                        systemImage: "tray.and.arrow.down",
                        title: "可选导入演示数据",
                        subtitle: "首次使用可以生成 5 个任务和 2 个日程，方便确认 Top 3、接下来和 Loose Ends 的展示形态。"
                    )
                    Toggle("创建演示任务与日程", isOn: $seedDemo)
                        .toggleStyle(.switch)
                        .frame(maxWidth: 360, alignment: .leading)
                }
                .tag(2)
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .always))
            #endif

            HStack {
                Button("跳过") {
                    onboardingCompleted = true
                }
                .disabled(isFinishing)

                Spacer()

                Button(page == 2 ? "进入 100J" : "下一步") {
                    Task { await advance() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isFinishing)
            }
            .padding()
        }
        .frame(minWidth: 420, minHeight: 420)
    }

    @MainActor
    private func advance() async {
        if page < 2 {
            withAnimation(.snappy) { page += 1 }
            return
        }
        isFinishing = true
        defer { isFinishing = false }
        if seedDemo {
            guard await model.seedDemo() else { return }
        }
        onboardingCompleted = true
    }
}

private struct OnboardingPageView: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.companyAccent)
            Text(title)
                .font(.largeTitle.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .frame(maxWidth: 520)
        }
        .padding(36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MeshGradientBackdrop())
    }
}
