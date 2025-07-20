import 'package:flutter/material.dart';
import 'package:tools/admin/models/domain.dart';

class DomainTile extends StatelessWidget {
  final DomainModel domain;
  final Function onEdit;
  final Function onDelete;
  final Function onTap;

  DomainTile({
    required this.domain,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(domain.name), // Menggunakan nama domain
      subtitle: Text(
        'ID: ${domain.id}',
      ), // Menampilkan ID Domain jika diperlukan
      onTap: () => onTap(),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: Icon(Icons.edit), onPressed: () => onEdit()),
          IconButton(icon: Icon(Icons.delete), onPressed: () => onDelete()),
        ],
      ),
    );
  }
}
