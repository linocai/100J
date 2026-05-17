import Foundation
import PersonalAffairsCore
import SwiftUI

struct AgentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var command = "create_task"
    @State private var argumentsText = "{\n  \"title\": \"Agent task\"\n}"
    @State private var dryRun = true
    @State private var responseText = ""
    @State private var confirmationToken = ""
    @State private var provider = "openai"
    @State private var apiKey = ""

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 16) {
                header
                agentCommandPanel
                confirmationPanel
                llmKeyPanel
                Spacer()
            }
            .padding()
            .frame(minWidth: 480)

            VStack(alignment: .leading, spacing: 12) {
                Text("Agent Tools")
                    .font(.headline)
                List(model.agentTools) { tool in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tool.name)
                            .font(.headline)
                        Text(tool.description)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                Text("Action Logs")
                    .font(.headline)
                List(model.agentLogs) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(log.actionType)
                            .font(.headline)
                        HStack {
                            BadgeText(text: log.status, color: log.status == "success" ? .green : .orange)
                            if let targetType = log.targetType {
                                BadgeText(text: targetType)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .frame(minWidth: 420)
        }
        .task {
            await model.run {
                model.agentTools = try await model.agentRepository.tools()
                model.agentLogs = try await model.agentRepository.logs()
                model.llmKey = try await model.agentRepository.llmKey()
            }
        }
    }

    private var header: some View {
        ToolbarTitle(title: "Agent", subtitle: "App-internal commands with dry run, confirmation, and action logs.")
    }

    private var agentCommandPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Command")
                .font(.headline)
            Picker("Command", selection: $command) {
                ForEach(model.agentTools.map(\.name), id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            TextField("Arguments JSON", text: $argumentsText, axis: .vertical)
                .font(.system(.body, design: .monospaced))
                .lineLimit(7...12)
                .textFieldStyle(.roundedBorder)
            Toggle("Dry run", isOn: $dryRun)
            HStack {
                Button {
                    execute()
                } label: {
                    Label("Execute", systemImage: "paperplane")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    Task {
                        await model.run {
                            model.agentLogs = try await model.agentRepository.logs()
                        }
                    }
                } label: {
                    Label("Refresh Logs", systemImage: "arrow.clockwise")
                }
            }
            if !responseText.isEmpty {
                Text(responseText)
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var confirmationPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Confirmation")
                .font(.headline)
            TextField("Confirmation token", text: $confirmationToken)
                .textFieldStyle(.roundedBorder)
            Button {
                confirm()
            } label: {
                Label("Confirm", systemImage: "checkmark.seal")
            }
            .disabled(confirmationToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var llmKeyPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LLM Key")
                .font(.headline)
            if let key = model.llmKey, key.isActive {
                Text("Current: \(key.provider) \(key.keyPreview ?? "")")
                    .foregroundStyle(.secondary)
            } else {
                Text("No key saved")
                    .foregroundStyle(.secondary)
            }
            HStack {
                TextField("Provider", text: $provider)
                    .textFieldStyle(.roundedBorder)
                SecureField("API key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                Button("Save") {
                    Task {
                        await model.run {
                            model.llmKey = try await model.agentRepository.saveLLMKey(provider: provider, apiKey: apiKey)
                            apiKey = ""
                        }
                    }
                }
                .disabled(provider.isEmpty || apiKey.isEmpty)
            }
        }
    }

    private func execute() {
        Task {
            await model.run {
                let arguments = try parseArguments(argumentsText)
                let response = try await model.agentRepository.execute(command: command, arguments: arguments, dryRun: dryRun)
                responseText = render(response)
                if let token = response.confirmationToken {
                    confirmationToken = token
                }
                try await model.loadAllData()
            }
        }
    }

    private func confirm() {
        Task {
            await model.run {
                let response = try await model.agentRepository.confirm(token: confirmationToken)
                responseText = render(response)
                confirmationToken = ""
                try await model.loadAllData()
            }
        }
    }
}

private func parseArguments(_ text: String) throws -> [String: JSONValue] {
    let data = Data(text.utf8)
    let object = try JSONSerialization.jsonObject(with: data)
    guard let dictionary = object as? [String: Any] else { return [:] }
    return dictionary.mapValues { JSONValue.fromAny($0) }
}

private func render(_ response: AgentCommandResponse) -> String {
    var lines = ["status: \(response.status)"]
    if let reason = response.reason {
        lines.append("reason: \(reason)")
    }
    if let token = response.confirmationToken {
        lines.append("confirmation_token: \(token)")
    }
    if let result = response.result {
        lines.append("result: \(result)")
    }
    if let wouldExecute = response.wouldExecute {
        lines.append("would_execute: \(wouldExecute)")
    }
    return lines.joined(separator: "\n")
}

