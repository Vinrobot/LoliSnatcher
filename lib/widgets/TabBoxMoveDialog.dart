import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:LoliSnatcher/SearchGlobals.dart';
import 'package:LoliSnatcher/widgets/SettingsWidgets.dart';

class TabBoxMoveDialog extends StatefulWidget {
  const TabBoxMoveDialog({Key? key, required this.row, required this.index}) : super(key: key);
  final Widget row;
  final int index;

  @override
  State<TabBoxMoveDialog> createState() => _TabBoxMoveDialogState();
}

class _TabBoxMoveDialogState extends State<TabBoxMoveDialog> {
  final SearchHandler searchHandler = SearchHandler.instance;

  final TextEditingController indexController = TextEditingController();

  @override
  void initState() {
    super.initState();

    indexController.text = (widget.index + 1).toString();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsDialog(
      contentItems: <Widget>[
        SizedBox(width: double.maxFinite, child: widget.row),
        // 
        const SizedBox(height: 10),
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
            side: BorderSide(color: Theme.of(context).colorScheme.secondary),
          ),
          onTap: () async {
            searchHandler.moveTab(widget.index, 0);
            Navigator.of(context).pop(true);
            Navigator.of(context).pop(true);
          },
          leading: const Icon(Icons.vertical_align_top),
          title: const Text('To Top'),
        ),
        // 
        const SizedBox(height: 10),
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
            side: BorderSide(color: Theme.of(context).colorScheme.secondary),
          ),
          onTap: () async {
            searchHandler.moveTab(widget.index, searchHandler.total);
            Navigator.of(context).pop(true);
            Navigator.of(context).pop(true);
          },
          leading: const Icon(Icons.vertical_align_bottom),
          title: const Text('To Bottom'),
        ),
        // 
        const SizedBox(height: 30),
        SettingsTextInput(
          title: "Tab Number",
          hintText: "Tab Number",
          onlyInput: true,
          controller: indexController,
          inputType: const TextInputType.numberWithOptions(signed: false, decimal: false),
          numberButtons: true,
          resetText: () => (widget.index + 1).toString(),
          numberStep: 1,
          numberMin: 1,
          numberMax: searchHandler.total.toDouble(),
          onChanged: (String value) {
            setState(() { });
          },
        ),
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
            side: BorderSide(color: Theme.of(context).colorScheme.secondary),
          ),
          onTap: () async {
            final int? enteredIndex = int.tryParse(indexController.text);
            if(enteredIndex == null) {
              Get.snackbar("Error", "Invalid tab number - Invalid input", snackPosition: SnackPosition.BOTTOM);
              return;
            } else {
              if(enteredIndex < 0 || enteredIndex > searchHandler.total) {
                Get.snackbar("Error", "Invalid tab number - Out of range", snackPosition: SnackPosition.BOTTOM);
                return;
              }

              searchHandler.moveTab(widget.index, enteredIndex - 1);
              Navigator.of(context).pop(true);
              Navigator.of(context).pop(true);
            }
          },
          leading: const Icon(Icons.vertical_align_center),
          title: const Text('To Set Number'),
        ),
        // 
        const SizedBox(height: 10),
        const Text('Preview:'),
        const SizedBox(height: 10),
        TabMovePreview(
          index: widget.index,
          indexController: indexController,
        ),
      ],
    );
  }
}

class TabMovePreview extends StatelessWidget {
  const TabMovePreview({
    Key? key,
    required this.index,
    required this.indexController,
  }) : super(key: key);

  final int index;
  final TextEditingController indexController;

  @override
  Widget build(BuildContext context) {
    final SearchHandler searchHandler = SearchHandler.instance;

    int enteredIndex = int.tryParse(indexController.text) ?? index;

    if(enteredIndex < 1) {
      enteredIndex = index;
    } else if(enteredIndex > searchHandler.total) {
      enteredIndex = index;
    }

    final int prevTabIndex = enteredIndex - 2;
    final SearchGlobal? prevTab = searchHandler.getTabByIndex(prevTabIndex);

    final int nextTabIndex = enteredIndex;
    final SearchGlobal? nextTab = searchHandler.getTabByIndex(nextTabIndex);

    final SearchGlobal currentTab = searchHandler.getTabByIndex(index)!;
    final SearchGlobal firstTab = searchHandler.getTabByIndex(0)!;
    final SearchGlobal lastTab = searchHandler.getTabByIndex(searchHandler.total - 1)!;

    final bool showFirst = enteredIndex > 2;
    final bool showFirstDots = showFirst && (enteredIndex > 1) && (enteredIndex - 1 > 2); // is first tab shown and entered number is bigger than 2 and possible prev tab number is bigger than 2
    final bool showLast = enteredIndex < searchHandler.total - 1;
    final bool showLastDots = showLast && (enteredIndex < searchHandler.total) && (enteredIndex + 1 < searchHandler.total - 1); // is last tab shown and entered number is smaller than total and possible next tab number is smaller than total - 1

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if(showFirst)
          Container(
            margin: const EdgeInsets.only(left: 10, bottom: 10),
            child: ElevatedButton(
              child: Text('#1 - ${firstTab.tags}'),
              onPressed: () {
                indexController.text = "1";
              },
            ),
          ),
        if(showFirstDots)
          Container(
            margin: const EdgeInsets.only(left: 10, bottom: 5),
            child: const Text("..."),
          ),
        // 
        if(prevTab != null)
          Container(
            margin: const EdgeInsets.only(left: 10, bottom: 10),
            child: ElevatedButton(
              child: Text('#${prevTabIndex + 1} - ${prevTab.tags}'),
              onPressed: () {
                indexController.text = (prevTabIndex + 1).toString();
              },
            ),
          ),
        // 
        Container(
          margin: const EdgeInsets.only(left: 10, bottom: 10),
          child: ElevatedButton(
            style: Theme.of(context).elevatedButtonTheme.style!.copyWith(
              backgroundColor: MaterialStateProperty.all<Color>(Colors.transparent),
              side: MaterialStateProperty.all<BorderSide>(BorderSide(color: Theme.of(context).colorScheme.secondary, width: 2)),
            ),
            child: Text(
              '#$enteredIndex - ${currentTab.tags}',
            ),
            onPressed: () {
              indexController.text = (index + 1).toString();
            },
          ),
        ),
        // 
        if(nextTab != null)
          Container(
            margin: const EdgeInsets.only(left: 10, bottom: 10),
            child: ElevatedButton(
              child: Text('#${nextTabIndex + 1} - ${nextTab.tags}'),
              onPressed: () {
                indexController.text = (nextTabIndex + 1).toString();
              },
            ),
          ),
        // 
        if(showLastDots)
          Container(
            margin: const EdgeInsets.only(left: 10, bottom: 5),
            child: const Text("..."),
          ),
        if(showLast)
          Container(
            margin: const EdgeInsets.only(left: 10),
            child: ElevatedButton(
              child: Text('#${searchHandler.total} - ${lastTab.tags}'),
              onPressed: () {
                indexController.text = searchHandler.total.toString();
              },
            ),
          ),
        
      ],
    );
  }
}