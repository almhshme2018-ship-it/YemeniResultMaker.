import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('certificateBox');

  runApp(const CertificateApp());
}

class CertificateApp extends StatelessWidget {
  const CertificateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'صانع الشهادات اليمني الذكي',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        fontFamily: 'NotoNaskhArabic',
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class LocalAIEngine {
  static String phrase({
    required bool award,
    required String gender,
    required String rank,
  }) {
    final female = gender == 'طالبة';

    if (award) {
      final pronoun = female ? 'تفوقها' : 'تفوقه';

      return 'تقديرًا $pronoun الدراسي المتميز، وحصول'
          '${female ? 'ها' : 'ه'}'
          ' على $rank، وما أظهر'
          '${female ? 'ته' : 'ه'}'
          ' من جد واجتهاد وحرص على النجاح والتميز، متمنين له'
          '${female ? 'ا' : ''}'
          ' دوام التوفيق والنجاح.';
    }

    return 'تقديرًا لنجاح'
        '${female ? 'ها' : 'ه'}'
        ' وجهود'
        '${female ? 'ها' : 'ه'}'
        ' المبذولة خلال العام الدراسي، وتشجيعًا له'
        '${female ? 'ا' : ''}'
        ' على مواصلة الجد والاجتهاد وتحقيق المزيد من النجاح والتفوق.';
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final box = Hive.box('certificateBox');

  final ImagePicker picker = ImagePicker();

  final name = TextEditingController();
  final school = TextEditingController();
  final location = TextEditingController();
  final manager = TextEditingController();
  final teacher = TextEditingController();
  final title = TextEditingController();
  final body = TextEditingController();
  final closing = TextEditingController();
  final year = TextEditingController(text: '1448هـ / 2026م');
  final grade = TextEditingController();
  final section = TextEditingController();

  bool award = true;
  String gender = 'طالب';
  String rank = 'الأول';
  String template = 'ذهبي';
  bool landscape = true;

  Uint8List? logo;

  List<Map<String, dynamic>> students = [];

  final templates = const [
    'ذهبي',
    'أخضر',
    'أزرق',
    'مزخرف',
    'بسيط',
  ];

  final ranks = const [
    'الأول',
    'الأول مكرر',
    'الثاني',
    'الثاني مكرر',
    'الثالث',
    'الثالث مكرر',
  ];

  @override
  void initState() {
    super.initState();

    school.text = box.get(
      'school',
      defaultValue: 'مدرسة جعفر بن أبي طالب الأساسية',
    );

    location.text = box.get(
      'location',
      defaultValue: 'الجمهورية اليمنية - إب - مذيخرة - الأشعوب',
    );

    manager.text = box.get('manager', defaultValue: '');
    teacher.text = box.get('teacher', defaultValue: '');
    year.text = box.get('year', defaultValue: '1448هـ / 2026م');

    logo = _readBytes(box.get('logo'));

    _loadDefaultText();

    final raw = box.get(
      'students',
      defaultValue: <dynamic>[],
    );

    students = raw
        .map<Map<String, dynamic>>(
          (e) => Map<String, dynamic>.from(e as Map),
        )
        .toList();
  }

  Uint8List? _readBytes(dynamic value) {
    if (value is Uint8List) {
      return value;
    }

    if (value is List) {
      return Uint8List.fromList(value.cast<int>());
    }

    return null;
  }

  void _loadDefaultText() {
    final defaults = box.get(
      'texts',
      defaultValue: <dynamic, dynamic>{},
    );

    final map = Map<String, dynamic>.from(defaults as Map);

    title.text =
        map['title'] ??
        (award ? 'شهادة تقديرية' : 'شهادة تشجيعية');

    body.text =
        map['body'] ??
        LocalAIEngine.phrase(
          award: award,
          gender: gender,
          rank: rank,
        );

    closing.text =
        map['closing'] ??
        'مع خالص التقدير والتمنيات بمزيد من النجاح والتفوق';
  }

  void _saveSettings() {
    box.putAll({
      'school': school.text.trim(),
      'location': location.text.trim(),
      'manager': manager.text.trim(),
      'teacher': teacher.text.trim(),
      'year': year.text.trim(),
      'texts': {
        'title': title.text,
        'body': body.text,
        'closing': closing.text,
      },
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حفظ إعدادات المدرسة والنصوص'),
      ),
    );
  }

  Future<void> _pickLogo() async {
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1200,
    );

    if (file == null) {
      return;
    }

    logo = await file.readAsBytes();

    await box.put('logo', logo);

    setState(() {});
  }

  Future<void> _addStudent() async {
    if (name.text.trim().isEmpty) {
      _msg('أدخل اسم الطالب أولاً');
      return;
    }

    final student = {
      'name': name.text.trim(),
      'gender': gender,
      'grade': grade.text.trim(),
      'section': section.text.trim(),
      'year': year.text.trim(),
      'award': award,
      'rank': rank,
    };

    students.add(student);

    await box.put('students', students);

    name.clear();

    setState(() {});

    _msg('تمت إضافة الطالب إلى القائمة');
  }

  Future<void> _removeStudent(int index) async {
    students.removeAt(index);

    await box.put('students', students);

    setState(() {});
  }

  void _msg(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  // ============================================================
  // PDF
  // ============================================================

  Future<pw.Document> _buildPdf(
    List<Map<String, dynamic>> records,
  ) async {
    final regularData = await rootBundle.load(
      'assets/fonts/NotoNaskhArabic-Regular.ttf',
    );

    final boldData = await rootBundle.load(
      'assets/fonts/NotoNaskhArabic-Bold.ttf',
    );

    final regular = pw.Font.ttf(regularData);
    final bold = pw.Font.ttf(boldData);

    final doc = pw.Document();

    final pageFormat =
        landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

    final emblem = _emblemSvg();

    final logoImage =
        logo == null ? null : pw.MemoryImage(logo!);

    for (final student in records) {
      final isAward = student['award'] == true;

      final studentGender =
          (student['gender'] ?? 'طالب').toString();

      final studentRank =
          (student['rank'] ?? rank).toString();

      final studentName =
          (student['name'] ?? '').toString();

      final studentGrade =
          (student['grade'] ?? grade.text).toString();

      final studentSection =
          (student['section'] ?? section.text).toString();

      final phrase = body.text;

      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(18),
          theme: pw.ThemeData.withFont(
            base: regular,
            bold: bold,
          ),
          build: (ctx) {
            return _certificatePage(
              regular: regular,
              bold: bold,
              studentName: studentName,
              gender: studentGender,
              rank: studentRank,
              isAward: isAward,
              studentGrade: studentGrade,
              studentSection: studentSection,
              phrase: phrase,
              closingText: closing.text,
              logoImage: logoImage,
              emblem: emblem,
            );
          },
        ),
      );
    }

    return doc;
  }

  String _emblemSvg() {
    return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 150">
  <g stroke="#222" stroke-width="3" stroke-linejoin="round">
    <path
      fill="#e6b84b"
      d="M120 28 C92 3 57 8 30 30
         L70 45 C53 56 39 73 28 91
         L83 67 C92 84 101 91 120 101
         C139 91 148 84 157 67
         L212 91 C201 73 187 56 170 45
         L210 30 C183 8 148 3 120 28Z"/>

    <path
      fill="#fff"
      d="M120 48 L151 66 L141 112
         L120 126 L99 112 L89 66Z"/>

    <path
      fill="#2e8b57"
      d="M120 57 C109 49 98 58 103 72
         C109 65 115 64 120 70
         C125 64 131 65 137 72
         C142 58 131 49 120 57Z"/>

    <path
      fill="#57a9e8"
      d="M101 86 Q120 75 139 86
         L137 105 Q120 114 103 105Z"/>

    <path
      fill="#d9aa46"
      d="M67 124 Q120 139 173 124
         L164 137 Q120 148 76 137Z"/>

    <path
      fill="#ed1c24"
      d="M25 121 Q67 135 91 142
         L86 149 Q52 140 17 126Z"/>

    <path
      fill="#111"
      d="M215 121 Q173 135 149 142
         L154 149 Q188 140 223 126Z"/>
  </g>
</svg>
''';
  }

  // ============================================================
  // CERTIFICATE PAGE
  // ============================================================

  pw.Widget _certificatePage({
    required pw.Font regular,
    required pw.Font bold,
    required String studentName,
    required String gender,
    required String rank,
    required bool isAward,
    required String studentGrade,
    required String studentSection,
    required String phrase,
    required String closingText,
    pw.MemoryImage? logoImage,
    required String emblem,
  }) {
    final scheme = _scheme(template);

    final top = pw.Row(
      mainAxisAlignment:
          pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment:
          pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 75,
          height: 70,
          child: logoImage == null
              ? pw.SizedBox()
              : pw.Image(
                  logoImage,
                  fit: pw.BoxFit.contain,
                ),
        ),

        pw.Expanded(
          child: pw.Column(
            children: [
              pw.SvgImage(
                svg: emblem,
                height: 62,
              ),

              pw.Text(
                'الجمهورية اليمنية',
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 15,
                ),
              ),

              pw.Text(
                'وزارة التربية والتعليم والبحث العلمي',
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 13,
                ),
              ),

              pw.SizedBox(height: 2),

              pw.Text(
                school.text,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 13,
                  color: scheme['accent'] as PdfColor,
                ),
              ),

              pw.Text(
                location.text,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: regular,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),

        const pw.SizedBox(
          width: 75,
          height: 70,
        ),
      ],
    );

    final titleText = title.text;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: scheme['border'] as PdfColor,
          width: 5,
        ),
      ),

      padding: const pw.EdgeInsets.all(12),

      child: pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(
            color: scheme['accent'] as PdfColor,
            width: 1.5,
          ),
        ),

        padding: const pw.EdgeInsets.symmetric(
          horizontal: 26,
          vertical: 16,
        ),

        child: pw.Directionality(
          textDirection: pw.TextDirection.rtl,

          child: pw.Column(
            children: [
              top,

              pw.SizedBox(height: 6),

              pw.Divider(
                color: scheme['accent'] as PdfColor,
                thickness: 1,
              ),

              pw.SizedBox(height: 8),

              pw.Text(
                titleText,
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 28,
                  color: scheme['title'] as PdfColor,
                ),
              ),

              pw.SizedBox(height: 8),

              pw.Text(
                isAward
                    ? 'تتقدم إدارة المدرسة بخالص التهاني والتقدير إلى:'
                    : 'تتقدم إدارة المدرسة بخالص التهنئة والتشجيع إلى:',
                style: pw.TextStyle(
                  font: regular,
                  fontSize: 14,
                ),
              ),

              pw.SizedBox(height: 6),

              pw.Text(
                studentName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 27,
                  color: scheme['name'] as PdfColor,
                ),
              ),

              pw.SizedBox(height: 5),

              pw.Text(
                '${gender == 'طالبة' ? 'الطالبة' : 'الطالب'}'
                '  |  الصف: '
                '${studentGrade.isEmpty ? '........' : studentGrade}'
                '  |  الشعبة: '
                '${studentSection.isEmpty ? '........' : studentSection}',
                style: pw.TextStyle(
                  font: regular,
                  fontSize: 12,
                ),
              ),

              if (isAward) ...[
                pw.SizedBox(height: 5),

                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),

                  decoration: pw.BoxDecoration(
                    color: scheme['soft'] as PdfColor,
                    borderRadius:
                        pw.BorderRadius.circular(10),
                  ),

                  child: pw.Text(
                    'المركز: $rank',
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 16,
                      color: scheme['accent'] as PdfColor,
                    ),
                  ),
                ),
              ],

              pw.SizedBox(height: 12),

              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),

                child: pw.Text(
                  phrase,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    font: regular,
                    fontSize: 14,
                    lineSpacing: 5,
                  ),
                ),
              ),

              pw.SizedBox(height: 4),

              pw.Text(
                closingText,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 12,
                  color: scheme['accent'] as PdfColor,
                ),
              ),

              pw.Spacer(),

              pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Text(
                        'المعلم',
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 12,
                        ),
                      ),

                      pw.SizedBox(height: 12),

                      pw.Text(
                        teacher.text.isEmpty
                            ? '....................'
                            : teacher.text,
                        style: pw.TextStyle(
                          font: regular,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),

                  pw.Column(
                    children: [
                      pw.Text(
                        'مدير المدرسة',
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 12,
                        ),
                      ),

                      pw.SizedBox(height: 12),

                      pw.Text(
                        manager.text.isEmpty
                            ? '....................'
                            : manager.text,
                        style: pw.TextStyle(
                          font: regular,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 8),

              pw.Text(
                year.text,
                style: pw.TextStyle(
                  font: regular,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // COLORS / TEMPLATES
  // ============================================================

  Map<String, dynamic> _scheme(String templateName) {
    switch (templateName) {
      case 'أخضر':
        return {
          'border': PdfColors.green800,
          'accent': PdfColors.green700,
          'title': PdfColors.green900,
          'name': PdfColors.green800,
          'soft': PdfColors.green100,
        };

      case 'أزرق':
        return {
          'border': PdfColors.blue800,
          'accent': PdfColors.blue700,
          'title': PdfColors.blue900,
          'name': PdfColors.blue800,
          'soft': PdfColors.blue100,
        };

      case 'مزخرف':
        return {
          'border': PdfColors.deepOrange,
          'accent': PdfColors.amber800,
          'title': PdfColors.brown800,
          'name': PdfColors.deepOrange800,
          'soft': PdfColors.amber100,
        };

      case 'بسيط':
        return {
          'border': PdfColors.grey700,
          'accent': PdfColors.grey800,
          'title': PdfColors.black,
          'name': PdfColors.grey900,
          'soft': PdfColors.grey200,
        };

      default:
        return {
          'border': PdfColors.amber800,
          'accent': PdfColors.amber700,
          'title': PdfColors.green900,
          'name': PdfColors.blue900,
          'soft': PdfColors.amber100,
        };
    }
  }

  // ============================================================
  // PDF ACTIONS
  // ============================================================

  Future<void> _previewSingle() async {
    if (name.text.trim().isEmpty) {
      _msg('أدخل اسم الطالب أولاً');
      return;
    }

    final doc = await _buildPdf([
      {
        'name': name.text.trim(),
        'gender': gender,
        'grade': grade.text.trim(),
        'section': section.text.trim(),
        'award': award,
        'rank': rank,
      }
    ]);

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'شهادة_${name.text.trim()}.pdf',
    );
  }

  Future<void> _previewBatch() async {
    if (students.isEmpty) {
      _msg('لا توجد أسماء في قائمة الطلاب');
      return;
    }

    final doc = await _buildPdf(students);

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'شهادات_الطلاب.pdf',
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
        ),
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,

      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'صانع الشهادات اليمني الذكي',
          ),
          centerTitle: true,
        ),

        body: ListView(
          padding: const EdgeInsets.all(14),

          children: [
            // نوع الشهادة
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),

                child: Column(
                  children: [
                    const Text(
                      'نوع الشهادة',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          label: Text('🏆 الأوائل'),
                          icon: Icon(Icons.emoji_events),
                        ),

                        ButtonSegment(
                          value: false,
                          label: Text('🌟 الناجحون'),
                          icon: Icon(Icons.star),
                        ),
                      ],

                      selected: {award},

                      onSelectionChanged: (value) {
                        setState(() {
                          award = value.first;

                          title.text = award
                              ? 'شهادة تقديرية'
                              : 'شهادة تشجيعية';

                          body.text =
                              LocalAIEngine.phrase(
                            award: award,
                            gender: gender,
                            rank: rank,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            // بيانات الطالب
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),

                child: Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'بيانات الطالب',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    _field(
                      name,
                      'اسم الطالب / الطالبة',
                    ),

                    DropdownButtonFormField<String>(
                      value: gender,
                      decoration: const InputDecoration(
                        labelText: 'الجنس',
                      ),

                      items: const [
                        DropdownMenuItem(
                          value: 'طالب',
                          child: Text('طالب'),
                        ),
                        DropdownMenuItem(
                          value: 'طالبة',
                          child: Text('طالبة'),
                        ),
                      ],

                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          gender = value;

                          body.text =
                              LocalAIEngine.phrase(
                            award: award,
                            gender: gender,
                            rank: rank,
                          );
                        });
                      },
                    ),

                    const SizedBox(height: 10),

                    if (award)
                      DropdownButtonFormField<String>(
                        value: rank,
                        decoration: const InputDecoration(
                          labelText: 'المركز',
                        ),

                        items: ranks
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),

                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            rank = value;

                            body.text =
                                LocalAIEngine.phrase(
                              award: award,
                              gender: gender,
                              rank: rank,
                            );
                          });
                        },
                      ),

                    if (award)
                      const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            grade,
                            'الصف',
                          ),
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: _field(
                            section,
                            'الشعبة',
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _addStudent,
                            icon: const Icon(
                              Icons.person_add,
                            ),
                            label: const Text(
                              'إضافة للقائمة',
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _previewSingle,
                            icon: const Icon(
                              Icons.picture_as_pdf,
                            ),
                            label: const Text(
                              'إنشاء الشهادة',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // القالب والاتجاه
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),

                child: Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'القالب والاتجاه',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      value: template,
                      decoration: const InputDecoration(
                        labelText: 'قالب الشهادة',
                      ),

                      items: templates
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                'قالب $item',
                              ),
                            ),
                          )
                          .toList(),

                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            template = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 10),

                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          label: Text('أفقي'),
                          icon: Icon(
                            Icons.crop_landscape,
                          ),
                        ),

                        ButtonSegment(
                          value: false,
                          label: Text('عمودي'),
                          icon: Icon(
                            Icons.crop_portrait,
                          ),
                        ),
                      ],

                      selected: {landscape},

                      onSelectionChanged: (value) {
                        setState(() {
                          landscape = value.first;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            // الشعار والبيانات
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),

                child: Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'الشعار والبيانات الرسمية',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    if (logo != null)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: 8),
                        child: Image.memory(
                          logo!,
                          height: 80,
                        ),
                      ),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickLogo,
                            icon: const Icon(
                              Icons.add_photo_alternate,
                            ),
                            label: const Text(
                              'إضافة شعار المدرسة',
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await box.delete('logo');

                              setState(() {
                                logo = null;
                              });
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                            ),
                            label: const Text(
                              'حذف الشعار',
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    _field(
                      school,
                      'اسم المدرسة',
                    ),

                    _field(
                      location,
                      'الموقع',
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            manager,
                            'مدير المدرسة',
                          ),
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: _field(
                            teacher,
                            'المعلم',
                          ),
                        ),
                      ],
                    ),

                    _field(
                      year,
                      'العام الدراسي',
                    ),

                    ElevatedButton.icon(
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.save),
                      label: const Text(
                        'حفظ بيانات المدرسة',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // النصوص
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),

                child: Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'تخصيص نصوص الشهادة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    _field(
                      title,
                      'عنوان الشهادة',
                    ),

                    _field(
                      body,
                      'نص الشهادة',
                      maxLines: 5,
                    ),

                    _field(
                      closing,
                      'العبارة الختامية',
                      maxLines: 2,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saveSettings,
                            icon: const Icon(
                              Icons.save,
                            ),
                            label: const Text(
                              'حفظ النصوص',
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                title.text = award
                                    ? 'شهادة تقديرية'
                                    : 'شهادة تشجيعية';

                                body.text =
                                    LocalAIEngine.phrase(
                                  award: award,
                                  gender: gender,
                                  rank: rank,
                                );

                                closing.text =
                                    'مع خالص التقدير والتمنيات بمزيد من النجاح والتفوق';
                              });
                            },
                            icon: const Icon(
                              Icons.restore,
                            ),
                            label: const Text(
                              'استعادة الافتراضي',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // الطلاب
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),

                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'قائمة الطلاب',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        Text(
                          '${students.length} طالب/طالبة',
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    if (students.isEmpty)
                      const Text(
                        'لم تتم إضافة طلاب بعد.',
                      ),

                    ...students.asMap().entries.map(
                      (entry) {
                        final student = entry.value;

                        final resultText =
                            student['award'] == true
                                ? '🏆 ${student['rank']}'
                                : '🌟 ناجح';

                        final gradeText =
                            '${student['grade'] ?? ''} '
                            '${student['section'] ?? ''}';

                        return ListTile(
                          title: Text(
                            student['name'].toString(),
                          ),

                          subtitle: Text(
                            '$resultText  |  $gradeText',
                          ),

                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                            ),
                            onPressed: () =>
                                _removeStudent(entry.key),
                          ),
                        );
                      },
                    ),

                    if (students.isNotEmpty)
                      SizedBox(
                        width: double.infinity,

                        child: ElevatedButton.icon(
                          onPressed: _previewBatch,
                          icon: const Icon(
                            Icons.picture_as_pdf,
                          ),
                          label: const Text(
                            'إنشاء شهادات القائمة كلها في PDF واحد',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Center(
              child: Text(
                'يعمل التطبيق محليًا دون الحاجة إلى الإنترنت',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
