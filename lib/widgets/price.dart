import 'package:flutter/material.dart';
import 'package:minsk8/import.dart';

Widget buildPrice(ItemModel item) {
  return Tooltip(
    message: 'Price',
    child: Material(
      color: Colors.yellow,
      borderRadius: BorderRadius.all(kImageBorderRadius),
      child: InkWell(
        splashColor: Colors.white,
        borderRadius: BorderRadius.all(kImageBorderRadius),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: 5,
            horizontal: 16.3,
          ),
          child: Text(
            item.price == null ? '0' : item.price?.toString(),
            style: TextStyle(
              fontSize: 23,
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: _onTap(item),
      ),
    ),
  );
}

Function _onTap(ItemModel item) => () {};
