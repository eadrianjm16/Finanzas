import SwiftUI
import SwiftData

struct DebtorDetailView: View {
    @Bindable var debtor: Debtor
    @Environment(\.modelContext) private var modelContext
    @State private var showingRegisterPayment = false
    @State private var showingAddDebt = false
    @State private var showingCancelConfirm = false
    @State private var amountText = ""

    private var sortedEntries: [DebtEntry] {
        debtor.entries.sorted { $0.date > $1.date }
    }

    private var balance: Decimal {
        debtor.entries.reduce(Decimal(0)) { $0 + $1.amount }
    }

    /// true = el saldo está a favor del usuario (te debe); false = el usuario le debe a él.
    private var isOwedToMe: Bool { balance >= 0 }

    private var balanceLabel: String {
        if balance > 0 { return "Te debe" }
        if balance < 0 { return "Le debes" }
        return "Al día"
    }

    private var balanceColor: Color {
        if balance > 0 { return .red }
        if balance < 0 { return .orange }
        return .secondary
    }

    private var paymentButtonLabel: String {
        isOwedToMe ? "Registrar pago recibido" : "Registrar pago realizado"
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text(balanceLabel)
                        .font(.headline)
                    Spacer()
                    Text(String(format: "%.2f €", NSDecimalNumber(decimal: abs(balance)).doubleValue))
                        .font(.title3.bold())
                        .foregroundStyle(balanceColor)
                }
            }

            Section {
                Button(paymentButtonLabel) {
                    amountText = ""
                    showingRegisterPayment = true
                }
                .disabled(balance == 0)
                Button("Añadir deuda manual") {
                    showingAddDebt = true
                }
                Button("Marcar deuda como cancelada", role: .destructive) {
                    showingCancelConfirm = true
                }
                .disabled(balance == 0)
            }

            Section("Historial") {
                if sortedEntries.isEmpty {
                    Text("Sin movimientos todavía")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedEntries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.note ?? "Movimiento")
                                Text(entry.date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(formattedAmount(entry.amount))
                                .foregroundStyle(amountColor(for: entry))
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { modelContext.delete(sortedEntries[index]) }
                        try? modelContext.save()
                    }
                }
            }
        }
        .navigationTitle(debtor.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert(paymentButtonLabel, isPresented: $showingRegisterPayment) {
            TextField("Importe", text: $amountText)
                .keyboardType(.decimalPad)
            Button("Cancelar", role: .cancel) {}
            Button("Registrar") { registerPayment() }
        } message: {
            Text(isOwedToMe
                 ? "Se restará del total que te debe \(debtor.name)."
                 : "Se restará del total que le debes a \(debtor.name).")
        }
        .sheet(isPresented: $showingAddDebt) {
            AddDebtEntrySheet(debtor: debtor)
        }
        .confirmationDialog(
            "¿Marcar la deuda como cancelada?",
            isPresented: $showingCancelConfirm,
            titleVisibility: .visible
        ) {
            Button("Cancelar deuda", role: .destructive) { cancelAllDebt() }
        } message: {
            Text("Se registrará un ajuste para dejar el saldo con \(debtor.name) en 0,00 €.")
        }
    }

    private func formattedAmount(_ amount: Decimal) -> String {
        let sign = amount > 0 ? "+" : (amount < 0 ? "-" : "")
        return "\(sign)\(String(format: "%.2f €", NSDecimalNumber(decimal: abs(amount)).doubleValue))"
    }

    private func amountColor(for entry: DebtEntry) -> Color {
        let note = entry.note ?? ""
        if note.contains("cancelada") { return .blue }
        if note.contains("Pago") { return .green }
        return entry.amount < 0 ? .orange : .primary
    }

    private func registerPayment() {
        guard let amount = Decimal(string: amountText.replacingOccurrences(of: ",", with: ".")), amount > 0 else { return }
        let entry = DebtEntry(
            amount: isOwedToMe ? -amount : amount,
            note: isOwedToMe ? "Pago recibido" : "Pago realizado"
        )
        entry.debtor = debtor
        modelContext.insert(entry)
        try? modelContext.save()
    }

    private func cancelAllDebt() {
        guard balance != 0 else { return }
        let entry = DebtEntry(amount: -balance, note: "Deuda cancelada")
        entry.debtor = debtor
        modelContext.insert(entry)
        try? modelContext.save()
    }
}

private struct AddDebtEntrySheet: View {
    let debtor: Debtor
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var kind: Kind = .owedToMe
    @State private var amountText = ""
    @State private var noteText = ""

    enum Kind: String, CaseIterable {
        case owedToMe = "Deuda a cobrar"
        case iOwe = "Deuda a pagar"
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Tipo", selection: $kind) {
                    ForEach(Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                TextField("Importe", text: $amountText)
                    .keyboardType(.decimalPad)
                TextField("Nota (opcional)", text: $noteText)
            }
            .navigationTitle("Deuda manual")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Añadir") { save() }
                        .disabled(!isValidAmount)
                }
            }
        }
    }

    private var isValidAmount: Bool {
        guard let value = Decimal(string: amountText.replacingOccurrences(of: ",", with: ".")) else { return false }
        return value > 0
    }

    private func save() {
        guard let value = Decimal(string: amountText.replacingOccurrences(of: ",", with: ".")), value > 0 else { return }
        let trimmedNote = noteText.trimmingCharacters(in: .whitespaces)
        let defaultNote = kind == .owedToMe ? "Deuda" : "Deuda (le debo)"
        let entry = DebtEntry(
            amount: kind == .owedToMe ? value : -value,
            note: trimmedNote.isEmpty ? defaultNote : trimmedNote
        )
        entry.debtor = debtor
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
    }
}
