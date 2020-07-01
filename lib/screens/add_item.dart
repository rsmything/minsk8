import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:extended_image/extended_image.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:minsk8/import.dart';

// TODO: прятать клавиатуру перед showDialog(), чтобы убрать анимацию диалога

enum ImageUploadStatus { loading, error }

class AddItemScreen extends StatefulWidget {
  AddItemScreen(this.arguments);

  final AddItemRouteArguments arguments;

  @override
  _AddItemScreenState createState() {
    return _AddItemScreenState();
  }
}

class _AddItemScreenState extends State<AddItemScreen> {
  // final _formKey = GlobalKey<FormState>();
  TextEditingController _textController;
  // bool isLoading = false;
  bool _isSubmited = false;
  ImageSource _imageSource;
  List<_ImageData> _images = [];
  UrgentStatus _urgent = UrgentStatus.not_urgent;
  KindValue _kind;
  FocusNode _textFocusNode;
  StorageUploadTask _uploadTask;
  Future<void> _uploadQueue = Future.value();

  String get _urgentName =>
      urgents
          .firstWhere((UrgentModel element) => element.value == _urgent,
              orElse: () => null)
          ?.name ??
      '';
  bool get _isValidText => _text.length > 3;
  String get _text => _textController.value.text.trim();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_onAfterBuild);
    _textController = TextEditingController(text: '');
    _kind = widget.arguments.kind;
    _textFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final panelChildWidth = size.width - 32.0; // for padding
    final gridSpacing = 8.0;
    // final child = Form(key: _formKey, child:
    final child = Column(
      children: [
        Container(
          padding: EdgeInsets.only(top: 16),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: (panelChildWidth - gridSpacing) / 2,
                width: panelChildWidth,
                child: GridView.count(
                  crossAxisSpacing: gridSpacing,
                  crossAxisCount: 2,
                  children: [
                    _buildAddImageButton(0),
                    GridView.count(
                      mainAxisSpacing: gridSpacing,
                      crossAxisSpacing: gridSpacing,
                      crossAxisCount: 2,
                      children: List.generate(
                        4,
                        (i) => _buildAddImageButton(i + 1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.white,
          child: TextField(
            autofocus: false,
            enableSuggestions: false,
            keyboardType: TextInputType.multiline,
            maxLines: null,
            controller: _textController,
            focusNode: _textFocusNode,
            decoration: InputDecoration(
              hintText: 'Часы Casio. Рабочие.',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Container(
          constraints: BoxConstraints(minHeight: 40),
          child: SelectButton(
            tooltip: 'Как срочно надо отдать?',
            text: 'Срочно?',
            rightText: _urgentName,
            onTap: _selectUrgent,
          ),
        ),
        Container(
          constraints: BoxConstraints(minHeight: 40),
          child: SelectButton(
            tooltip: 'Категория',
            text: kinds.firstWhere((element) => element.value == _kind).name,
            onTap: _selectKind,
          ),
        ),
        Container(
          constraints: BoxConstraints(minHeight: 40),
          child: SelectButton(
            tooltip: 'Местоположение',
            text: appState['address'] ?? 'Местоположение',
            onTap: _selectLocation,
          ),
        ),
        Spacer(),
        Container(
          height: kBigButtonHeight,
          width: panelChildWidth,
          child: ReadyButton(onTap: _handleAddItem),
        ),
        SizedBox(
          height: 16,
        ),
      ],
    );
    // Expanding content to fit the viewport
    final body = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints viewportConstraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: viewportConstraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: child,
            ),
          ),
        );
      },
    );
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Что отдаёте?'),
          actions: [
            IconButton(
              tooltip: 'Подтвердить',
              icon: Icon(Icons.check),
              onPressed: _handleAddItem,
            ),
          ],
        ),
        body: body,
      ),
    );
  }

  void _onAfterBuild(Duration timeStamp) {
    showImageSourceDialog(context).then((ImageSource imageSource) {
      if (imageSource == null) return;
      _pickImage(0, imageSource).then((bool result) {
        if (!result) return;
        _imageSource = imageSource;
      });
    });
  }

  void _handleAddItem() async {
    await _uploadQueue;
    // if (isLoading) {
    //   return;
    // }
    if (!_isValidText) {
      showDialog(
        context: context,
        child: AlertDialog(
          content: Text('Опишите лот: что это, состояние, размер...'),
          actions: [
            FlatButton(
              child: Text('ОК'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ).then((_) {
        _textFocusNode.requestFocus();
      });
      return;
    }
    if (_images.length == 0) {
      showDialog(
        context: context,
        child: AlertDialog(
          content: Text('Добавьте фотографию лота'),
          actions: [
            FlatButton(
              child: Text('ОК'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
      return;
    }
    // TODO: добавить CANCEL в диалог, если подвисла загрузка (или Timeout?)
    showDialog(
      context: context,
      barrierDismissible: false,
      child: AlertDialog(
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            buildProgressIndicator(context),
            SizedBox(width: 16),
            Text('Загрузка...'),
          ],
        ),
      ),
    );
    final GraphQLClient client = GraphQLProvider.of(context).value;
    final options = MutationOptions(
      documentNode: Mutations.insertItem,
      variables: {
        'images': _images.map((element) => element.model.toJson()).toList(),
        'text': _text, // TODO: как защитить от атаки?
        'urgent': EnumToString.parse(_urgent),
        'kind': EnumToString.parse(_kind),
        'location': {
          'type': 'Point',
          'coordinates': appState['center'],
        },
        'address': appState['address'],
      },
      fetchPolicy: FetchPolicy.noCache,
    );
    client
        .mutate(options)
        .timeout(Duration(seconds: kGraphQLMutationTimeout))
        .then((QueryResult result) async {
      if (result.hasException) {
        throw result.exception;
      }
      final itemData = result.data['insert_item_one'];
      final newItem = ItemModel.fromJson(itemData);
      final profile = Provider.of<ProfileModel>(context, listen: false);
      profile.member.items.insert(0, newItem);
      _reloadTab(_kind);
      _reloadTab(MetaKindValue.recent);
      Navigator.of(context).pop(); // for showDialog "Загрузка..."
      final value = await showDialog(
        context: context,
        child: AddedItemDialog(
          newItem,
          needModerate: _kind == KindValue.service,
        ),
      );
      if (value ?? false) {
        final kind = await Navigator.of(context).pushReplacementNamed('/kinds');
        if (kind == null) return;
        Navigator.pushNamed(
          homeKey.currentContext, // hack
          '/add_item',
          arguments: AddItemRouteArguments(
            kind: kind,
            tabIndex: widget.arguments.tabIndex,
          ),
        );
        return;
      }
      Navigator.of(context).pushReplacementNamed(
        '/item',
        arguments: ItemRouteArguments(
          newItem,
          member: profile.member,
        ),
      );
    }).catchError((error) {
      debugPrint(error.toString());
      // TODO: сообщение пользователю об ошибке
      Navigator.of(context).pop();
    });
    // await Future.delayed(const Duration(seconds: 1));
    // return;
    // if (!_formKey.currentState.validate()) {
    //   return;
    // }
    // setState(() {
    //   isLoading = true;
    // });
    // try {
    //   // Navigator.pushReplacementNamed(
    //   //   context,
    //   // );
    // } catch (e) {
    //   // setState(() {
    //   //   isLoading = false;
    //   // });
    //   print(e);
    // }
  }

  Widget _buildAddImageButton(int index) {
    return AddImageButton(
      index: index,
      hasIcon: _images.length == index,
      onTap: _images.length > index ? _handleDeleteImage : _handleAddImage,
      bytes: _images.length > index ? _images[index].bytes : null,
    );
  }

  void _handleAddImage(int index) {
    if (_imageSource == null) {
      showImageSourceDialog(context).then((ImageSource imageSource) {
        if (imageSource == null) return;
        _pickImage(index, imageSource).then((bool result) {
          if (!result) return;
          _imageSource = imageSource;
        });
      });
      return;
    }
    _pickImage(index, _imageSource);
  }

  void _handleDeleteImage(int index) {
    // if (_cancelUploadImage()) {
    // }

    setState(() {
      _images.removeAt(index);
    });
  }

  Future<bool> _pickImage(int index, ImageSource imageSource) async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.getImage(source: imageSource).catchError((error) {
      debugPrint(error.toString());
    });
    if (pickedFile == null) return false;
    final bytes = await pickedFile.readAsBytes();
    final imageData = _ImageData(bytes);
    setState(() {
      if (index < _images.length) {
        _images.removeAt(index);
        _images.insert(index, imageData);
      } else {
        _images.add(imageData);
      }
    });
    _uploadQueue = _uploadQueue.then((_) => _uploadImage(imageData));
    _uploadQueue = _uploadQueue.timeout(Duration(seconds: kImageUploadTimeout));
    _uploadQueue = _uploadQueue.catchError((error) {
      if (error is TimeoutException) {
        if (_cancelUploadImage())
          setState(() {
            _images.remove(imageData);
          });
        // TODO: сообщение пользователю об ошибке
      }
      debugPrint(error.toString());
    });
    return true;
  }

  Future<void> _uploadImage(_ImageData imageData) async {
    // final completer = Completer<void>();
    // // TODO: FirebaseStorage ругается "no auth token for request"
    // final storage =
    //     // FirebaseStorage.instance;
    //     FirebaseStorage(storageBucket: kStorageBucket);
    // final filePath = 'images/${DateTime.now()} ${Uuid().v4()}.png';
    // // TODO: оптимизировать размер данных картинок перед выгрузкой
    // final uploadTask = storage.ref().child(filePath).putData(bytes);
    // final streamSubscription = uploadTask.events.listen((event) async {
    //   // TODO: if (event.type == StorageTaskEventType.progress)
    //   if (event.type != StorageTaskEventType.success) return;
    //   final downloadUrl = await event.snapshot.ref.getDownloadURL();
    //   final image = ExtendedImage.memory(bytes);
    //   final size = await _calculateImageDimension(image);
    //   imageData.model = ImageModel(
    //     url: downloadUrl,
    //     width: size.width,
    //     height: size.height,
    //   );
    //   await Future.delayed(Duration(seconds: 10));
    //   completer.complete();
    // });
    // await uploadTask.onComplete;
    // streamSubscription.cancel();
    // await completer.future;
    final filePath = 'images/${DateTime.now()} ${Uuid().v4()}.png';
    final storageReference = FirebaseStorage.instance.ref().child(filePath);
    _uploadTask = storageReference.putData(imageData.bytes);
    final streamSubscription = _uploadTask.events.listen((event) async {
      if (event.type == StorageTaskEventType.progress) {
        print(
            'progress ${event.snapshot.bytesTransferred} / ${event.snapshot.totalByteCount}');
      }
      // TODO: добавить индикатор загрузки и кнопку отмены
    });
    await _uploadTask.onComplete;
    await streamSubscription.cancel();
    final isCanceled = _uploadTask.isCanceled;
    _uploadTask = null;
    if (isCanceled) return;
    final downloadUrl = await storageReference.getDownloadURL();
    final image = ExtendedImage.memory(imageData.bytes);
    final size = await _calculateImageDimension(image);
    imageData.model = ImageModel(
      url: downloadUrl,
      width: size.width,
      height: size.height,
    );
  }

  bool _cancelUploadImage() {
    try {
      if (_uploadTask.isComplete || _uploadTask.isCanceled) return false;
      // если сразу вызвать снаружи, то падает - обернул в try-catch
      _uploadTask.cancel();
      return true;
    } catch (error) {
      debugPrint(error.toString());
    }
    return false;
  }

  Future<SizeInt> _calculateImageDimension(ExtendedImage image) {
    final completer = Completer<SizeInt>();
    image.image.resolve(ImageConfiguration()).addListener(
      ImageStreamListener(
        (ImageInfo image, bool synchronousCall) {
          final myImage = image.image;
          final size = SizeInt(myImage.width, myImage.height);
          completer.complete(size);
        },
      ),
    );
    return completer.future;
  }

  void _selectUrgent() {
    selectUrgentDialog(context, _urgent).then((UrgentStatus value) {
      if (value == null) return;
      setState(() {
        _urgent = value;
      });
    });
  }

  void _selectKind() {
    Navigator.pushNamed(
      context,
      '/kinds',
      arguments: KindsRouteArguments(_kind),
    ).then((kind) {
      if (kind == null) return;
      setState(() {
        _kind = kind;
      });
    });
  }

  void _selectLocation() {
    Navigator.pushNamed(
      context,
      '/my_item_map',
    ).then((value) {
      if (value == null) return;
      setState(() {});
    });
  }

  Future<bool> _onWillPop() async {
    if (_isSubmited) return true;
    if (_images.length == 0 && !_isValidText) return true;
    final result = await showCancelItemDialog(context);
    return result ?? false; // if enableDrag, result may be null
  }

  _reloadTab(kind) {
    final index = allKinds.indexWhere((element) => element.enumValue == kind);
    if (index == widget.arguments.tabIndex) {
      Showcase.pullToRefreshNotificationKey.currentState.show();
    } else if (!Showcase.poolForReloadTabs.contains(index)) {
      Showcase.poolForReloadTabs.add(index);
    }
  }
}

class AddItemRouteArguments {
  AddItemRouteArguments({this.kind, this.tabIndex});

  final KindValue kind;
  final int tabIndex;
}

class _ImageData {
  _ImageData(this.bytes);

  final Uint8List bytes;
  ImageModel model;
}
