import Foundation

/// Detecta movimientos que probablemente sean traspasos entre las propias
/// cuentas del usuario (p. ej. Santander -> ING) — el "No computable" de
/// Fintonic. Enable Banking no marca esto explícitamente; se infiere
/// emparejando un cargo en una cuenta con un abono en OTRA cuenta propia,
/// mismo importe y moneda, fecha cercana (misma ventana de 3 días que ya
/// usa AlertsEngine para duplicados). No es infalible — dos pagos externos
/// no relacionados podrían coincidir por casualidad — pero es una señal
/// razonable para uso personal con pocas cuentas.
enum InternalTransferDetector {
    private static let window: TimeInterval = 3 * 24 * 3600

    static func detect(_ transactions: [Transaction]) -> Set<String> {
        var flagged: Set<String> = []
        let grouped = Dictionary(grouping: transactions) { "\($0.amount)|\($0.currency)" }

        for (_, group) in grouped where group.count > 1 {
            for i in 0..<group.count {
                let a = group[i]
                guard !flagged.contains(a.entryReference) else { continue }
                for j in 0..<group.count where j != i {
                    let b = group[j]
                    guard a.account?.accountUID != nil,
                          a.account?.accountUID != b.account?.accountUID,
                          a.creditDebitIndicator != b.creditDebitIndicator,
                          abs(a.bookingDate.timeIntervalSince(b.bookingDate)) <= window
                    else { continue }
                    flagged.insert(a.entryReference)
                    flagged.insert(b.entryReference)
                    break
                }
            }
        }
        return flagged
    }
}
