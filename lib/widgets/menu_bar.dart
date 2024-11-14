import 'package:flutter/material.dart';

class CustomMenuBar extends StatelessWidget {
  final Function(String, String) onMenuSelected;

  CustomMenuBar({required this.onMenuSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30.0,
      color: Colors.grey[900], // Background color for the menu bar
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // File Menu
          _buildMenuItem(
            context,
            'File',
            ['Close'],
            (value) => onMenuSelected('File', value),
          ),
          // Edit Menu
          _buildMenuItem(
            context,
            'Edit',
            ['Preferences'],
            (value) => onMenuSelected('Edit', value),
          ),
          // Help Menu
          _buildMenuItem(
            context,
            'Help',
            ['About'],
            (value) => onMenuSelected('Help', value),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    String title,
    List<String> options,
    Function(String) onSelected,
  ) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) => options
          .map(
            (option) => PopupMenuItem<String>(
              value: option,
              child: Text(option),
            ),
          )
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14.0,
          ),
        ),
      ),
      color: Colors.grey[800], // Background color for dropdown
    );
  }
}
