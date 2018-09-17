import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fluttering_vikunja/api/client.dart';
import 'package:fluttering_vikunja/api/user_implementation.dart';
import 'package:fluttering_vikunja/managers/user.dart';
import 'package:fluttering_vikunja/models/user.dart';
import 'package:fluttering_vikunja/service/mocked_services.dart';
import 'package:fluttering_vikunja/service/services.dart';

class VikunjaGlobal extends StatefulWidget {
  final Widget child;
  final Widget login;

  VikunjaGlobal({this.child, this.login});

  @override
  VikunjaGlobalState createState() => VikunjaGlobalState();

  static VikunjaGlobalState of(BuildContext context) {
    var widget = context.inheritFromWidgetOfExactType(_VikunjaGlobalInherited)
        as _VikunjaGlobalInherited;
    return widget.data;
  }
}

class VikunjaGlobalState extends State<VikunjaGlobal> {
  final FlutterSecureStorage _storage = new FlutterSecureStorage();

  User _currentUser;
  Client _client;
  bool _loading = true;

  User get currentUser => _currentUser;
  Client get client => _client;

  UserManager get userManager => new UserManager(_storage);
  UserService get userService => new UserAPIService(_client);
  UserService newLoginService(base) => new UserAPIService(Client(null, base));

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  void changeUser(User newUser, {String token, String base}) async {
    setState(() {
      _loading = true;
    });
    if (token == null) {
      token = await _storage.read(key: newUser.id.toString());
    } else {
      // Write new token to secure storage
      await _storage.write(key: newUser.id.toString(), value: token);
    }
    if (base == null) {
      base = await _storage.read(key: "${newUser.id.toString()}_base");
    } else {
      // Write new base to secure storage
      await _storage.write(key: "${newUser.id.toString()}_base", value: base);
    }
    // Set current user in storage
    await _storage.write(key: 'currentUser', value: newUser.id.toString());
    setState(() {
      _currentUser = newUser;
      _client = Client(token, base);
      _loading = false;
    });
  }

  void _loadCurrentUser() async {
    var currentUser = await _storage.read(key: 'currentUser');
    if (currentUser == null) {
      setState(() {
        _loading = false;
      });
      return;
    }
    var token = await _storage.read(key: currentUser);
    var base = await _storage.read(key: '${currentUser}_base');
    if (token == null || base == null) {
      setState(() {
        _loading = false;
      });
      return;
    }
    setState(() {
      _client = Client(token, base);
    });
    var loadedCurrentUser = await userService.getCurrentUser();
    setState(() {
      _currentUser = loadedCurrentUser;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return new Center(child: new CircularProgressIndicator());
    }
    return new _VikunjaGlobalInherited(
      data: this,
      child: client == null ? widget.login : widget.child,
    );
  }
}

class _VikunjaGlobalInherited extends InheritedWidget {
  final VikunjaGlobalState data;

  _VikunjaGlobalInherited({Key key, this.data, Widget child})
      : super(key: key, child: child);

  @override
  bool updateShouldNotify(_VikunjaGlobalInherited oldWidget) {
    return (data.currentUser != null &&
            data.currentUser.id != oldWidget.data.currentUser.id) ||
        data.client != oldWidget.data.client;
  }
}
