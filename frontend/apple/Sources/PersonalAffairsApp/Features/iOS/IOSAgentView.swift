#if os(iOS)
import Foundation
import PersonalAffairsCore
import SwiftUI

struct IOSAgentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var command = "create_task"
    @State private var argumentsText = "{\n  \"title\": \"Agent task\"\n}"
    @State private var dryRun = true
    @State private var responseText = ""
    @State private var confirmationToken = ""
    @State private var showingConfirmation = false
    @State private var provider = "openai"
    @State private var apiKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    IOSScreenHeader(title: "Agent", subtitle: "App-internal commands with dry run, confirmation, and action logs.")
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }

                Section("Command") {
                    Picker("Command", selection: $command) {
                        ForEach(model.agentTools.map(\.name), id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    TextField("Arguments JSON", text: $argumentsText, axis: .vertical)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(6...12)
                    Toggle("Dry run", isOn: $dryRun)
                    Button("Execute") {
                        execute()
                    }
                }

                if !responseText.isEmpty {
                    Section("Response") {
                        Text(responseText)
                            .font(.system(.caption, design: .monospaced))
                    }
                }

                Section("Confirmation") {
                    TextField("Confirmation token", text: $confirmationToken)
                    Button("Confirm") {
                        confirm()
                    }
                    .disabled(confirmationToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("LLM Key") {
                    if let key = model.llmKey, key.isActive {
                        LabeledContent("Current", value: "\(key.provider) \(key.keyPreview ?? "")")
                    } else {
                        Text("No key saved")
                            .foregroundStyle(.secondary)
                    }
                    TextField("Provider", text: $provider)
                    SecureField("API key", text: $apiKey)
                    Button("Save Key") {
                        Task {
                            await model.run {
                                model.llmKey = try await model.agentRepository.saveLLMKey(provider: provider, apiKey: apiKey)
                                apiKey = ""
                            }
                        }
                    }
                    .disabled(provider.isEmpty || apiKey.isEmpty)
                }

                Section("Action Logs") {
                    ForEach(model.agentLogs) { log in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(log.actionType)
                                .font(.headline)
                            HStack {
                                IOSBadge(text: log.status, color: log.status == "success" ? .green : .orange)
                                if let targetType = log.targetType {
                                    IOSBadge(text: targetType)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Agent")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await reload()
            }
            .overlay { IOSLoadingOverlay() }
            .iosErrorAlert()
            .task {
                await reload()
            }
        }
    }

    private func reload() async {
        await model.run {
            model.agentTools = try await model.agentRepository.tools()
            model.agentLogs = try await model.agentRepository.logs()
            model.llmKey = try await model.agentRepository.llmKey()
        }
    }

    private func execute() {
        Task {
            await model.run {
                let arguments = try parseIOSArguments(argumentsText)
                let response = try await model.agentRepository.execute(command: command, arguments: arguments, dryRun: dryRun)
                responseText = renderIOSAgentResponse(response)
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
                responseText = renderIOSAgentResponse(response)
                confirmationToken = ""
                try await model.loadAllData()
            }
        }
    }
}

private func parseIOSArguments(_ text: String) throws -> [String: JSONValue] {
    let data = Data(text.utf8)
    let object = try JSONSerialization.jsonObject(with: data)
    guard let dictionary = object as? [String: Any] else { return [:] }
    return dictionary.mapValues { JSONValue.fromAny($0) }
}

private func renderIOSAgentResponse(_ response: AgentCommandResponse) -> String {
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
#endif

