import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ivex/main.dart';
import 'package:ivex/services/auth_controller.dart';

void main() {
  testWidgets('shows splash then login screen', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthController(),
        child: const IvexApp(),
      ),
    );

    expect(find.text('IVEX'), findsOneWidget);
    expect(find.text('Own Your Signature Look'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}

