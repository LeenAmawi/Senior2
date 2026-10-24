
import 'package:flutter/material.dart';
import 'Start2.dart';
import '../Auth/Login.dart';


class Start1 extends StatelessWidget {
  const Start1({super.key});
  static const Color purple = Color(0xFFB16BE5);
  static const Color blue = Color(0xFF168BFF);
  void goToNextPage(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => Start2(),),);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.white,body: SafeArea(
    child: LayoutBuilder(builder: (context, constraints) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Column(children: [
    Expanded(flex: 6, child: Center(
      child: Image.asset('assets/images/starting1.png', width: double.infinity, fit: BoxFit.contain,),),),
      const SizedBox(height: 8),
      const Text('Welcome to Kidsential\nKindergarten',textAlign: TextAlign.center,
      style: TextStyle(color: purple, fontSize: 19, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic, height: 1.3,),),
      const SizedBox(height: 20),
      const Text('Welcome to safe place for kids to\ngrow.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontSize: 15, height: 1.4,),),

      const Spacer(),
      Padding(padding: const EdgeInsets.only(left: 15, right: 5, bottom: 12,),
        child: Row(children: [GestureDetector(onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) =>  Login(),),);},
          child: const Text('skip', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic,),),),
          const Spacer(),
          Row(children: [
            _dot(blue),
            _dot(const Color(0xFFB8DEFF)),
            _dot(const Color(0xFFB8DEFF)),
          ],),
          const SizedBox(width: 8), IconButton(onPressed: () => goToNextPage(context),
            icon: const Icon(Icons.arrow_forward, color: blue, size: 28,),),],
        ),),
    ],),
    );
    },
    ),
    ),
    );}

  static Widget _dot(Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
