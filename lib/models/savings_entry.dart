/// Bolsillo de ahorro: nombre + monto guardado.
class SavingsEntry {
  SavingsEntry({
    required this.id,
    required this.name,
    required this.amount,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final double amount;
  final DateTime updatedAt;

  SavingsEntry copyWith({String? name, double? amount}) => SavingsEntry(
        id: id,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'updatedAt': updatedAt.toIso8601String(),
      };

  static SavingsEntry fromJson(Map<String, dynamic> j) => SavingsEntry(
        id: j['id'] as String,
        name: j['name'] as String,
        amount: (j['amount'] as num).toDouble(),
        updatedAt:
            DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );
}
