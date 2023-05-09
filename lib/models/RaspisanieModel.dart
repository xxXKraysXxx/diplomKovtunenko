// Copyright 2019 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// A proxy of the catalog of items the user can buy.
///
/// In a real app, this might be backed by a backend and cached on device.
/// In this sample app, the catalog is procedurally generated and infinite.
///
/// For simplicity, the catalog is expected to be immutable (no products are
/// expected to be added, removed or changed during the execution of the app).
class CatalogModel {
  static List<String> weekDay = [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
    '-',
  ];
  static List<String> cabinets = [
    '404',
    '103',
    '203л',
    'Дистанционно',
    'Спортзал',
    '-',
    '-',
  ];
  static List<String> teachers = [
    'Петрова П. П.',
    'Иванова А. Г.',
    'Ковтуненко А. А.',
    'Егоров Д. А.',
    'Амогус И. А.',
    '-',
    '-',
  ];

  static List<String> subjects = [
    'Высшая математика',
    'Литература',
    'Русский язык',
    'Английский язык',
    'Физкультура',
    '-',
    '-',
  ];


}

@immutable
class Item {
  final int id;

  final String cabinet;
  final String teacher;
  final String subject;


  Item(this.id, this.teacher, this.cabinet, this.subject)
      // To make the sample app look nicer, each item is given one of the
      // Material Design primary colors.
  ;
  // @override
  // int get hashCode => id;
  //
  // @override
  // bool operator ==(Object other) => other is Item && other.id == id;
}
