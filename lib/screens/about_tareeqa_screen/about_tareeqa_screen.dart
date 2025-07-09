// import 'package:card_swiper/card_swiper.dart';
// import 'package:flutter/material.dart';
//
// // map, dr. yoursi biography, teachings page, tareeqa map of people
// class AboutTareeqaScreen extends StatefulWidget {
//   const AboutTareeqaScreen({super.key});
//   final String title = '';
//   @override
//   State<AboutTareeqaScreen> createState() => _AboutTareeqaScreenState();
// }
//
// class _AboutTareeqaScreenState extends State<AboutTareeqaScreen> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('عن الطريقة'),
//       ),
//       body: Center(
//         child: Swiper(
//           itemBuilder: _buildItem,
//           axisDirection: AxisDirection.right,
//           itemCount: 3,
//           autoplay: true,
//           pagination: const SwiperPagination(),
//           control: SwiperControl(
//             color: Colors.green[700],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// Widget _buildItem(BuildContext context, int index) {
//   final String img;
//   final String btnText;
//   final String subtitle;
//   switch (index) {
//     case 0:
//       img = "assets/imgs/about_screen_1.jpg";
//       btnText = 'ترجمة الشيخ';
//       subtitle = 'شيخ الطريقة د يسري جبر';
//     // return _buildAboutScreen(context);
//     case 1:
//       img = "assets/imgs/about_screen_2.jpg";
//       btnText = 'سيند الطريقة';
//       subtitle = 'سند الطريقة المتصل من د يسري جبر إلى رسول الله ﷺ';
//     // return _buildAboutScreen(context);
//     case 2:
//     // return _buildAboutScreen(context);
//     default:
//       img = "assets/imgs/about_screen_1.jpg";
//       btnText = 'ترجمة الشيخ';
//       subtitle = 'شيخ الطريقة د يسري جبر';
//   }
//   return Column(
//     mainAxisAlignment: MainAxisAlignment.center,
//     children: [
//       ClipRRect(
//         borderRadius: const BorderRadius.all(Radius.circular(20)),
//         child: Image.asset(
//           width: MediaQuery.of(context).size.width * 0.8,
//           height: MediaQuery.of(context).size.height * 0.5,
//           // images[index % images.length],
//           img,
//           // "assets/imgs/about_screen_1.jpg",
//           fit: BoxFit.fitHeight,
//         ),
//       ),
//       const SizedBox(height: 15),
//       SizedBox(
//         width: MediaQuery.of(context).size.width * 0.7,
//         child: Text(
//           subtitle,
//           textAlign: TextAlign.center,
//           style: const TextStyle(
//             fontSize: 20,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ),
//       const SizedBox(height: 15),
//       ElevatedButton(
//         onPressed: () {},
//         child: Text(
//           btnText,
//         ),
//       ),
//     ],
//   );
// }
