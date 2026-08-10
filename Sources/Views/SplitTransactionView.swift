import SwiftUI
import SwiftData

struct SplitTransactionView: View {
    @Bindable var transaction: Transaction
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Debtor.name) private var debtors: [Debtor]

    @State private var selectedDebtorIDs: Set<PersistentIdentifier> = []
    @State private var includeMe = false
    @State private var mode: SplitMode = .equal
    @State private var fixedAmounts: [PersistentIdentifier: String] = [:]
    @State private var newDebtorName = ""
    @State private var showingAddDebtor = false
    @State private var errorMessage: String?

    enum SplitMode: String, CaseIterable {
        case equal = "Por igual"
        case fixed = "Cantidad fija"
    }

    private var total: Decimal { abs(transaction.amount) }

    private var selectedDebtors: [Debtor] {
        debtors.filter { selectedDebtorIDs.contains($0.persistentModelID) }
    }

    private var divisor: Int {
        selectedDebtors.count + (includeMe ? 1 : 0)
    }

    private var equalShare: Decimal {
        guard divisor > 0 else { return 0 }
        return total / Decimal(divisor)
    }

    private var fixedAssignedTotal: Decimal {
        selectedDebtors.reduce(Decimal(0)) { partial, debtor in
            guard let text = fixedAmounts[debtor.persistentModelID],
                  let amount = Decimal(string: text.replacingOccurrences(of: ",", with: ".")) else { return partial }
            return partial + amount
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Total del movimiento") {
                    Text(String(format: "%.2f €", NSDecimalNumber(decimal: total).doubleValue))
                        .font(.title3.bold())
                }

                Section {
                    Toggle("Incluirme en el reparto", isOn: $includeMe)
                    Picker("Modo", selection: $mode) {
                        ForEach(SplitMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Personas") {
                    ForEach(debtors) { debtor in
                        HStack {
                            Button {
                                toggle(debtor)
                            } label: {
                                Image(systemName: selectedDebtorIDs.contains(debtor.persistentModelID) ? "checkmark.circle.fill" : "circle")
                            }
                            .buttonStyle(.plain)
                            Text(debtor.name)
                            Spacer()
                            if selectedDebtorIDs.contains(debtor.persistentModelID) {
                                if mode == .equal {
                                    Text(String(format: "%.2f €", NSDecimalNumber(decimal: equalShare).doubleValue))
                                        .foregroundStyle(.secondary)
                                } else {
                                    TextField("0.00", text: Binding(
                                        get: { fixedAmounts[debtor.persistentModelID] ?? "" },
                                        set: { fixedAmounts[debtor.persistentModelID] = $0 }
                                    ))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                }
                            }
                        }
                    }
                    Button("Añadir persona nueva") {
                        newDebtorName = ""
                        showingAddDebtor = true
                    }
                }

                if mode == .fixed {
                    Section {
                        HStack {
                            Text("Asignado")
                            Spacer()
                            Text("\(fixedAssignedTotal, format: .number.precision(.fractionLength(2))) / \(total, format: .number.precision(.fractionLength(2))) €")
                                .foregroundStyle(fixedAssignedTotal > total ? .red : .secondary)
                        }
                    }
                }
            }
            .navigationTitle("Dividir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(!canSave)
                }
            }
            .alert("Nueva persona", isPresented: $showingAddDebtor) {
                TextField("Nombre", text: $newDebtorName)
                Button("Cancelar", role: .cancel) {}
                Button("Añadir") { addDebtor() }
            }
            .alert("Aviso", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var canSave: Bool {
        guard !selectedDebtors.isEmpty else { return false }
        if mode == .fixed { return fixedAssignedTotal <= total && fixedAssignedTotal > 0 }
        return divisor > 0
    }

    private func toggle(_ debtor: Debtor) {
        if selectedDebtorIDs.contains(debtor.persistentModelID) {
            selectedDebtorIDs.remove(debtor.persistentModelID)
        } else {
            selectedDebtorIDs.insert(debtor.persistentModelID)
        }
    }

    private func addDebtor() {
        let trimmed = newDebtorName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !debtors.contains(where: { $0.name == trimmed }) else {
            errorMessage = "Ya existe una persona con ese nombre"
            return
        }
        let debtor = Debtor(name: trimmed)
        modelContext.insert(debtor)
        try? modelContext.save()
        selectedDebtorIDs.insert(debtor.persistentModelID)
    }

    private func save() {
        for debtor in selectedDebtors {
            let amount: Decimal
            if mode == .equal {
                amount = equalShare
            } else {
                guard let text = fixedAmounts[debtor.persistentModelID],
                      let value = Decimal(string: text.replacingOccurrences(of: ",", with: ".")), value > 0 else { continue }
                amount = value
            }
            let entry = DebtEntry(
                amount: amount,
                date: transaction.bookingDate,
                note: transaction.counterpartyName ?? transaction.remittanceInformation
            )
            entry.debtor = debtor
            entry.transaction = transaction
            modelContext.insert(entry)
        }
        try? modelContext.save()
        dismiss()
    }
}
