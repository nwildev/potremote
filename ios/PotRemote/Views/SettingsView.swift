import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var vm: PlayerViewModel
    @State private var testResult: String?
    @State private var testing = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Сервер (PotPlayer Bridge на ПК)") {
                    TextField("IP-адрес, напр. 192.168.1.100", text: $vm.host)
                        .keyboardType(.decimalPad)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                    TextField("Порт", value: $vm.port, format: .number.grouping(.never))
                        .keyboardType(.numberPad)
                    SecureField("Токен (если задан на сервере)", text: $vm.token)
                }

                Section {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            Text("Проверить соединение")
                            Spacer()
                            if testing { ProgressView() }
                        }
                    }
                    if let testResult {
                        Label(testResult,
                              systemImage: testResult.hasPrefix("OK")
                                ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(testResult.hasPrefix("OK") ? .green : .red)
                    }
                } footer: {
                    Text("iPhone и ПК должны быть в одной локальной сети. На ПК запустите potplayer_bridge.py и разрешите порт в брандмауэре Windows.")
                }
            }
            .navigationTitle("Настройки")
        }
    }

    private func testConnection() {
        testing = true
        testResult = nil
        Task {
            defer { testing = false }
            do {
                let status = try await vm.client.status()
                testResult = status.connected
                    ? "OK: PotPlayer найден"
                    : "OK: сервер отвечает, но окно PotPlayer не найдено"
            } catch {
                testResult = "Ошибка: сервер недоступен"
            }
        }
    }
}
