import 'package:flutter/material.dart';
import 'package:minsk8/import.dart';

class EnumModelDialog<T extends EnumModel> extends StatelessWidget {
  EnumModelDialog({this.title, this.elements});

  final String title;
  final List<T> elements;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          elements.length,
          (index) => Material(
            color: Colors.white,
            child: InkWell(
              child: ListTile(
                title: Text(elements[index].enumName),
              ),
              onLongPress: () {}, // чтобы сократить время для splashColor
              onTap: () {
                Navigator.of(context).pop(elements[index].enumValue);
              },
            ),
          ),
        ),
      ),
      actions: [
        FlatButton(
          child: Text('Отмена'),
          onLongPress: () {}, // чтобы сократить время для splashColor
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
