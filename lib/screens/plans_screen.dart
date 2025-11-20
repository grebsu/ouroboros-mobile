import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/providers/plans_provider.dart';
import 'package:ouroboros_mobile/providers/all_subjects_provider.dart';
import 'package:ouroboros_mobile/screens/plan_detail_screen.dart';
import 'package:ouroboros_mobile/widgets/create_plan_modal.dart';
import 'package:ouroboros_mobile/widgets/import_guide_modal.dart';
import 'package:ouroboros_mobile/widgets/study_guide_loading_screen.dart';
import 'package:ouroboros_mobile/models/loading_state.dart';
import 'package:ouroboros_mobile/widgets/confirmation_modal.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  InAppWebViewController? _webViewController;
  final Completer<InAppWebViewController> _controllerCompleter = Completer<InAppWebViewController>();
  final ValueNotifier<LoadingState> _loadingStateNotifier = ValueNotifier<LoadingState>(
    LoadingState(currentStatus: 'Iniciando...', progress: 0.0),
  );
  final ScrollController _scrollController = ScrollController();
  WebUri? _currentNavigationUrl;
  Completer<void>? _pageNavigationCompleter;

  @override
  void initState() {
    super.initState();
    _controllerCompleter.future.then((controller) {
      _webViewController = controller;
      // Configura o onLoadStop para completar o Completer de navegação

    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // _webViewController?.dispose(); // Não chamar dispose aqui, pois o controller é gerenciado pela InAppWebView
    super.dispose();
  }

  final List<String> _subjectColors = [
    '#ef4444', '#f97316', '#eab308', '#84cc16', '#22c55e', '#14b8a6',
    '#06b6d4', '#3b82f6', '#8b5cf6', '#d946ef', '#f43f5e', '#64748b',
    '#f43f5e', '#be123c', '#9f1239', '#7f1d1d', '#7f1d1d', '#881337',
    '#9d174d', '#a21caf', '#86198f', '#7e22ce', '#6b21a8', '#5b21b6',
    '#4c1d95', '#312e81', '#1e3a8a', '#1e40af', '#1d4ed8', '#2563eb',
    '#3b82f6', '#0284c7', '#0369a1', '#075985', '#0891b2', '#0e7490',
    '#155e75', '#166534', '#14532d', '#16a34a', '#15803d', '#166534'
  ];

  String _cleanSubjectName(String rawName) {
    final stopWords = [' para ', ' - ', ' ('];
    int? firstStopIndex;

    for (final word in stopWords) {
      final index = rawName.indexOf(word);
      if (index != -1) {
        if (firstStopIndex == null || index < firstStopIndex) {
          firstStopIndex = index;
        }
      }
    }

    if (firstStopIndex != null) {
      return rawName.substring(0, firstStopIndex).trim();
    }

    return rawName.trim();
  }

  // Helper para navegar e aguardar o carregamento completo da página da matéria
  Future<void> _navigateToSubjectPage(InAppWebViewController controller, WebUri url) async {
    _pageNavigationCompleter = Completer<void>();
    _currentNavigationUrl = url;
    await controller.loadUrl(urlRequest: URLRequest(url: url));
    await _pageNavigationCompleter!.future.timeout(const Duration(seconds: 60), onTimeout: () {
      throw Exception('Timeout esperando o carregamento da página da matéria: $url');
    });
  }

  Future<Plan> _scrapeGuide(String url, ValueNotifier<LoadingState> loadingNotifier) async {
    loadingNotifier.value = loadingNotifier.value.copyWith(currentStatus: 'Aguardando WebView...', progress: 0.05);
    final controller = await _controllerCompleter.future.timeout(const Duration(seconds: 60), onTimeout: () {
      throw Exception('WebView controller not ready within 60 seconds.');
    });
    print('PlansScreen: WebView controller obtido.');
    print('PlansScreen: Iniciando scraping para URL: $url');

    loadingNotifier.value = loadingNotifier.value.copyWith(currentStatus: 'Extraindo cabeçalho e links de matérias...', progress: 0.1);
    final Map<String, dynamic> headerData = await _extractHeaderAndSubjectLinks(controller, url);
    print('PlansScreen: Header Data extraído: $headerData');

    // Download and save the image
    String? localIconPath;
    if (headerData['iconUrl'] != null && headerData['iconUrl'].isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(headerData['iconUrl']));
        final image = img.decodeImage(response.bodyBytes);

        if (image != null) {
          final resizedImage = img.copyResize(image, width: 512, height: 512);
          final Directory appDocDir = await getApplicationDocumentsDirectory();
          final String appDocPath = appDocDir.path;
          final String fileName = const Uuid().v4() + '.png';
          final String newPath = '$appDocPath/$fileName';
          final newImageFile = File(newPath);
          await newImageFile.writeAsBytes(img.encodePng(resizedImage));
          localIconPath = newImageFile.path;
        }
      } catch (e) {
        print('Error downloading or processing image: $e');
      }
    }

    final List<dynamic> subjectLinksDynamic = headerData['subjectLinks'];
    print('PlansScreen: Tipo de subjectLinksDynamic: ${subjectLinksDynamic.runtimeType}');
    print('PlansScreen: Conteúdo de subjectLinksDynamic: $subjectLinksDynamic');

    final List<Map<String, String>> subjectLinks = subjectLinksDynamic.map((item) => Map<String, String>.from(item)).toList();
    final List<Subject> finalSubjects = [];

    final int totalSubjectsToScrape = subjectLinks.length;
    int processedTopicsCount = 0; // To keep track of topics processed so far
    // overallTotalTopics is no longer needed as we only show current subtopics.

    loadingNotifier.value = loadingNotifier.value.copyWith(
      currentStatus: 'Iniciando extração de matérias...',
      totalSubjects: totalSubjectsToScrape,
      progress: 0.2,
    );
    print('PlansScreen: Iniciando extração de matérias. Total: ${subjectLinks.length}');
    for (var i = 0; i < subjectLinks.length; i++) {
      final subjectLink = subjectLinks[i];
      loadingNotifier.value = loadingNotifier.value.copyWith(
        currentStatus: 'Processando matéria: ${subjectLink['name']}',
        currentSubjects: i + 1,
        currentTopics: processedTopicsCount, // Update currentTopics here
        progress: 0.2 + (0.7 * (i / totalSubjectsToScrape)), // Progress from 0.2 to 0.9
      );
      print('PlansScreen: Processando matéria ${i + 1}/${subjectLinks.length}: ${subjectLink['name']} - ${subjectLink['url']}');
      List<Topic> bestTopics = [];
      int maxTopicsFound = 0;
      const int maxRetries = 3;

      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        print('PlansScreen: Tentativa $attempt para extrair tópicos de ${subjectLink['name']}');
        await _navigateToSubjectPage(controller, WebUri(subjectLink['url']!));
        final currentTopics = await _extractTopics(controller);
        final currentTopicCount = _calculateTotalTopicsRecursively(currentTopics);

        print('PlansScreen: Tentativa $attempt - Tópicos encontrados: $currentTopicCount para ${subjectLink['name']}');

        if (currentTopicCount > maxTopicsFound) {
          maxTopicsFound = currentTopicCount;
          bestTopics = currentTopics;
          print('PlansScreen: Nova melhor contagem de tópicos para ${subjectLink['name']}: $maxTopicsFound');
        }

        if (attempt < maxRetries) {
          await Future.delayed(const Duration(seconds: 2)); // Pequeno atraso antes de reententar
        }
      }
      
      if (bestTopics.isEmpty) {
        print('PlansScreen: Falha ao extrair quaisquer tópicos para ${subjectLink['name']} após $maxRetries tentativas.');
        // Considerar adicionar um tratamento de erro mais robusto aqui, como um log ou notificação ao usuário.
      }

      print('PlansScreen: Matéria ${subjectLink['name']} - Tópicos finais selecionados: ${bestTopics.length} (total calculado: $maxTopicsFound)');
      // Adicionando log detalhado dos tópicos finais
      try {
        final topicsJson = jsonEncode(bestTopics.map((t) => t.toMap()).toList());
        print('PlansScreen: Tópicos FINAIS para ${subjectLink['name']}: $topicsJson');
      } catch (e) {
        print('PlansScreen: Erro ao encodar tópicos finais para JSON: $e');
      }
      
      final int currentSubjectTopicsCount = maxTopicsFound;
      processedTopicsCount += currentSubjectTopicsCount;

      finalSubjects.add(Subject(
        id: const Uuid().v4(),
        plan_id: '', // Será preenchido depois
        subject: _cleanSubjectName(subjectLink['name']!),
        color: _subjectColors[i % _subjectColors.length],
        topics: bestTopics,
        total_topics_count: currentSubjectTopicsCount, // Use the actual count
        import_source: 'GUIDE',
      ));
    }

    // After the loop, overallTotalTopics is no longer needed as we only show current subtopics.
    // The total number of subtopics is not displayed.

    loadingNotifier.value = loadingNotifier.value.copyWith(
      currentStatus: 'Matérias e subtópicos extraídos. Finalizando...', // Updated status message
      currentSubjects: totalSubjectsToScrape,
      // totalTopics is intentionally not set here as per user request
      currentTopics: processedTopicsCount, // Set current topics here
      progress: 0.9,
    );

    final planId = const Uuid().v4();
    final subjectsWithPlanId = finalSubjects.map((s) => Subject(
      id: s.id, plan_id: planId, subject: s.subject, color: s.color, topics: s.topics, total_topics_count: s.total_topics_count, import_source: s.import_source
    )).toList();

    final plan = Plan(
      id: planId,
      name: headerData['name'] ?? '',
      cargo: headerData['cargo'],
      edital: headerData['edital'],
      banca: headerData['banca'],
      iconUrl: localIconPath,
      subjects: subjectsWithPlanId,
    );

    print('PlansScreen: Plano final montado: ${plan.name} com ${plan.subjects?.length ?? 0} matérias.');
    return plan;
  }

  Future<Map<String, dynamic>> _extractHeaderAndSubjectLinks(InAppWebViewController controller, String url) async {
    await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    await _waitForSelector(
      controller, 
      'div.guias-cabecalho, div.cadernos-agrupamento, div.detalhes-cabecalho', 
      textConditionJs: 'document.querySelector("span.cadernos-colunas-destaque") && !document.querySelector("span.cadernos-colunas-destaque").textContent.includes("{{")'
    );
    
    String getHeaderJs = """ 
      (function() {
        let name = document.querySelector('div.guias-cabecalho-concurso-nome')?.textContent?.trim() || 
                   document.querySelector('div.detalhes-cabecalho-informacoes-texto h1 span:not([class])')?.textContent?.trim() || 
                   document.title.split('-')[0].trim();
        let iconUrl = document.querySelector('div.guias-cabecalho-logo img')?.getAttribute('src') || 
                      document.querySelector('div.detalhes-cabecalho-logotipo img')?.getAttribute('src') || 
                      document.querySelector('img[alt*="logotipo"]')?.getAttribute('src') || '';
        
        let cargo = document.querySelector('span.detalhes-cabecalho-informacoes-orgao')?.textContent?.trim() ||
                    document.querySelector('div.guias-cabecalho-concurso-cargo')?.textContent?.trim() || '';

        let edital = document.querySelector('h2.detalhes-valores')?.textContent?.trim() ||
                     document.querySelector('div.guias-cabecalho-concurso-edital')?.textContent?.trim() || '';

        let banca = '';
        const bancaLabel = Array.from(document.querySelectorAll('span.detalhes-campos')).find(el => el.textContent?.trim() === 'Banca');
        if (bancaLabel && bancaLabel.nextElementSibling) {
            banca = (bancaLabel.nextElementSibling).textContent?.split('(')[0].trim() || '';
        }

        return { name, cargo, edital, iconUrl, banca };
      })();
    """;
    final headerData = await controller.evaluateJavascript(source: getHeaderJs);

    String getLinksJs = """ 
      (function() {
        const links = [];
        let subjectElementsGuia = document.querySelectorAll('div.guia-materia-item');
        console.log('subjectElementsGuia count:', subjectElementsGuia.length);
        if (subjectElementsGuia.length > 0) {
            subjectElementsGuia.forEach(el => {
                const anchor = el.querySelector('h4.guia-materia-item-nome a');
                if (anchor) {
                    const name = anchor.textContent?.trim();
                    const url = anchor.href;
                    if (name && name !== 'Inéditas' && url) {
                        links.push({name: name, url: url});
                    }
                }
            });
        } else {
            let subjectElementsCadernos = document.querySelectorAll('div.cadernos-item');
            console.log('subjectElementsCadernos count:', subjectElementsCadernos.length);
            subjectElementsCadernos.forEach(el => {
                console.log('Processing cadernos-item:', el.outerHTML);
                const nameEl = el.querySelector('span.cadernos-colunas-destaque');
                console.log('nameEl:', nameEl?.outerHTML, 'textContent:', nameEl?.textContent?.trim());
                const anchor = el.querySelector('a.cadernos-ver-detalhes');
                console.log('anchor:', anchor?.outerHTML, 'href:', anchor?.href);
                if (nameEl && anchor) {
                    const name = nameEl.textContent?.trim();
                    const url = anchor.href;
                    if (name && name !== 'Inéditas' && url) {
                        links.push({name: name, url: url});
                    }
                }
            });
        }
        return links;
      })();
    """;
    final linksResult = await controller.evaluateJavascript(source: getLinksJs) as List<dynamic>;
    print('PlansScreen: Links de matérias brutos: $linksResult');
    (headerData as Map<String, dynamic>)['subjectLinks'] = linksResult.map((item) => Map<String, String>.from(item)).toList();

    return headerData;
  }

  Future<List<Topic>> _extractTopics(InAppWebViewController controller) async {
    await _waitForSelector(controller, 'div.caderno-guia-arvore-indice ul');
    String getTopicsJs = """ 
      (function() {
        const processLis = (ulElement) => {
            const topics = [];
            Array.from(ulElement.children).forEach(child => {
                if (child.tagName !== 'LI') return;
                const span = child.querySelector(':scope > span');
                const topicText = span?.textContent?.trim();
                if (!topicText) return;

                const questionCountEl = child.querySelector('span.capitulo-questoes > span');
                let questionCount = 0;
                if (questionCountEl) {
                    const text = questionCountEl.textContent?.trim().toLowerCase();
                    if (text === 'uma questão') {
                        questionCount = 1;
                    } else if (text) {
                        const match = text.match(/(\d+)/);
                        if (match) {
                            questionCount = parseInt(match[1], 10);
                        }
                    }
                }

                const subUl = child.nextElementSibling;
                if (subUl && subUl.tagName === 'UL') {
                    const firstSubLi = subUl.querySelector(':scope > li');
                    if (firstSubLi) {
                        const firstSubQuestionCountEl = firstSubLi.querySelector('span.capitulo-questoes > span');
                        let firstSubQuestionCount = 0;
                        if (firstSubQuestionCountEl) {
                            const text = firstSubQuestionCountEl.textContent?.trim().toLowerCase();
                            if (text === 'uma questão') {
                                firstSubQuestionCount = 1;
                            } else if (text) {
                                const match = text.match(/(\d+)/);
                                if (match) {
                                    firstSubQuestionCount = parseInt(match[1], 10);
                                }
                            }
                        }
                        if (questionCount > 0 && questionCount === firstSubQuestionCount) {
                            const promotedTopics = processLis(subUl);
                            topics.push(...promotedTopics);
                            return;
                        }
                    }
                }
                
                const sub_topics = (subUl && subUl.tagName === 'UL') ? processLis(subUl) : [];
                topics.push({
                    topic_text: topicText,
                    sub_topics,
                    question_count: questionCount,
                    is_grouping_topic: sub_topics.length > 0
                });
            });
            return topics;
        };
        const mainTreeContainer = document.querySelector('div.caderno-guia-arvore-indice ul');
        if (!mainTreeContainer) return [];
        return processLis(mainTreeContainer);
      })();
    """;
    final topicsResult = await controller.evaluateJavascript(source: getTopicsJs) as List<dynamic>;
    return topicsResult.map((topicMap) => Topic.fromMap(topicMap)).toList();
  }

  Future<void> _waitForSelector(InAppWebViewController controller, String selector, {int timeout = 60000, String? textConditionJs, int stabilizationDuration = 3000}) async {
    final completer = Completer<void>();
    final stopwatch = Stopwatch()..start();
    int? lastLiCount;
    int? lastChangeTime;

    Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (stopwatch.elapsedMilliseconds > timeout) {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.completeError(Exception('Timeout esperando pelo seletor: $selector' + (textConditionJs != null ? ' com condição de texto: $textConditionJs' : '')));
        }
        return;
      }

      final selectorExists = await controller.evaluateJavascript(source: 'document.querySelector("$selector") != null');
      bool conditionMet = selectorExists == true;

      if (conditionMet && selector == 'div.caderno-guia-arvore-indice ul') {
        // Conta todos os LI descendentes, não apenas os diretos
        final currentLiCount = await controller.evaluateJavascript(source: 'document.querySelectorAll("$selector li").length');
        
        if (lastLiCount == null || currentLiCount != lastLiCount) {
          lastLiCount = currentLiCount;
          lastChangeTime = stopwatch.elapsedMilliseconds;
        } else if (stopwatch.elapsedMilliseconds - lastChangeTime! > stabilizationDuration) {
          // Li count has stabilized
          conditionMet = true;
        } else {
          conditionMet = false; // Still waiting for stabilization
        }
      }
      
      // Apply additional text condition if provided and primary condition is met
      if (conditionMet && textConditionJs != null) {
        final textConditionResult = await controller.evaluateJavascript(source: textConditionJs);
        conditionMet = textConditionResult == true;
      }

      if (conditionMet) {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    return completer.future;
  }

  Future<void> _handleImportGuide(String guideUrl) async {
    print('PlansScreen: _handleImportGuide chamado com URL: $guideUrl');
    // Reset loading state
    _loadingStateNotifier.value = LoadingState(currentStatus: 'Iniciando importação...', progress: 0.0);

    // Show loading screen
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StudyGuideLoadingScreen(loadingStateNotifier: _loadingStateNotifier);
      },
    );

    try {
      final Plan planData = await _scrapeGuide(guideUrl, _loadingStateNotifier); // Pass notifier

      final plansProvider = Provider.of<PlansProvider>(context, listen: false);
      final allSubjectsProvider = Provider.of<AllSubjectsProvider>(context, listen: false);

      // Update status for saving data
      _loadingStateNotifier.value = _loadingStateNotifier.value.copyWith(
        currentStatus: 'Salvando dados do plano...',
        progress: 0.9, // Near completion
      );

      Plan? existingPlan = await plansProvider.getPlanByName(planData.name);
      String planId;

      if (existingPlan != null) {
        planId = existingPlan.id;
      } else {
        final newPlan = await plansProvider.addPlan(
          name: planData.name,
          observations: planData.observations,
          cargo: planData.cargo,
          edital: planData.edital,
          banca: planData.banca,
          iconUrl: planData.iconUrl,
        );
        planId = newPlan.id;
      }

      if (planData.subjects != null) {
        final subjectsWithCorrectPlanId = planData.subjects!.map((s) => Subject(
          id: s.id,
          plan_id: planId, // Use o ID do plano recém-criado
          subject: s.subject,
          color: s.color,
          topics: s.topics,
          total_topics_count: s.total_topics_count,
        )).toList();

        for (var subjectData in subjectsWithCorrectPlanId) {
          Subject? existingSubject = await allSubjectsProvider.getSubjectByNameAndPlanId(subjectData.subject, planId);

          if (existingSubject != null) {
            final updatedSubject = Subject(
              id: existingSubject.id,
              plan_id: planId,
              subject: subjectData.subject,
              topics: subjectData.topics,
              color: existingSubject.color, // Keep the existing color
              total_topics_count: subjectData.total_topics_count,
            );
            await allSubjectsProvider.updateSubject(updatedSubject);
          } else {
            final newSubject = Subject(
              id: const Uuid().v4(),
              plan_id: planId,
              subject: subjectData.subject,
              topics: subjectData.topics,
              color: subjectData.color,
              total_topics_count: subjectData.total_topics_count,
            );
            await allSubjectsProvider.addSubject(newSubject);
          }
        }
      }

      await Provider.of<AllSubjectsProvider>(context, listen: false).fetchData();
      await Provider.of<PlansProvider>(context, listen: false).fetchPlans();

      _loadingStateNotifier.value = _loadingStateNotifier.value.copyWith(
        currentStatus: 'Importação concluída!',
        progress: 1.0,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plano "${planData.name}" importado com sucesso!')),
      );

    } catch (e) {
      print('PlansScreen: Erro durante a importação do guia: $e');
      _loadingStateNotifier.value = _loadingStateNotifier.value.copyWith(
        currentStatus: 'Erro: ${e.toString()}',
        progress: 0.0,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao importar o guia: $e')), 
      );
    } finally {
      // Dismiss loading screen
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('PlansScreen: build chamado.');
    return Stack(
      children: [
        Scaffold(
          body: Consumer<PlansProvider>(
            builder: (context, provider, child) {
              print('PlansScreen Consumer: isLoading=${provider.isLoading}, plans.isEmpty=${provider.plans.isEmpty}');
              if (provider.isLoading && provider.plans.isEmpty) {
                return const Center(child: CircularProgressIndicator(color: Colors.teal));
              }
              if (provider.plans.isEmpty) {
                return _buildEmptyState(context);
              }
              return _buildPlansList(context, provider.plans);
            },
          ),
        ),
        SizedBox(
          width: 0,
          height: 0,
          child: Offstage(
            offstage: true,
            child: InAppWebView(
              initialSettings: InAppWebViewSettings(
                javaScriptCanOpenWindowsAutomatically: true,
                javaScriptEnabled: true,
                domStorageEnabled: true,
                userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.127 Safari/537.36",
                builtInZoomControls: false,
                supportZoom: false,
                useWideViewPort: true,
                initialScale: 100,
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
                _controllerCompleter.complete(controller);
              },
              onLoadStop: (controller, url) async {
                if (_pageNavigationCompleter != null && !_pageNavigationCompleter!.isCompleted && url == _currentNavigationUrl) {
                  _pageNavigationCompleter!.complete();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, size: 80, color: Colors.teal),
            const SizedBox(height: 16),
            const Text(
              'Nenhum plano de estudo encontrado.',
              style: TextStyle(fontSize: 18, color: Colors.teal),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return const CreatePlanModal();
                  },
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Crie seu primeiro plano'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text('OU', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Card(
              elevation: 2.0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Importar Guia do Tec Concursos',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8.0),
                    const Text('Importe um plano de estudos diretamente de um guia do Tec Concursos.'),
                    const SizedBox(height: 16.0),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return ImportGuideModal(onImport: _handleImportGuide);
                            },
                          );
                        },
                        icon: const Icon(Icons.cloud_download),
                        label: const Text('Importar Guia'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlansList(BuildContext context, List<Plan> plans) {
    final orientation = MediaQuery.of(context).orientation;
    final crossAxisCount = orientation == Orientation.portrait ? 2 : 4;

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          Card(
            elevation: 4.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Importar Guia do Tec Concursos',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8.0),
                  const Text('Importe um plano de estudos diretamente de um guia do Tec Concursos.'),
                  const SizedBox(height: 16.0),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return ImportGuideModal(onImport: _handleImportGuide);
                          },
                        );
                      },
                      icon: const Icon(Icons.cloud_download),
                      label: const Text('Importar Guia'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24.0),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: 0.7,
            ),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlanDetailScreen(plan: plan),
                    ),
                  );
                },
                child: _buildPlanCard(context, plan),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, Plan plan) {
    final stats = Provider.of<PlansProvider>(context, listen: false).planStats[plan.id] ?? (subjectCount: 0, topicCount: 0);

    return Card(
      elevation: 6.0, // Aumenta a elevação para um efeito mais pronunciado
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)), // Bordas mais arredondadas
      clipBehavior: Clip.antiAlias, // Garante que o conteúdo seja cortado pelas bordas arredondadas
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlanDetailScreen(plan: plan),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0), // Padding consistente
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Estica os elementos horizontalmente
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribui o espaço verticalmente
            children: <Widget>[
              // Ícone ou imagem do plano
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1), // Fundo suave com a cor primária
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: plan.iconUrl != null && plan.iconUrl!.isNotEmpty
                        ? Image.file(
                            File(plan.iconUrl!),
                            height: 64,
                            width: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(Icons.assignment, size: 48, color: Theme.of(context).primaryColor), // Ícone padrão com cor primária
                          )
                        : Icon(Icons.assignment, size: 48, color: Theme.of(context).primaryColor), // Ícone padrão com cor primária
                  ),
                ),
              ),
              const SizedBox(height: 16), // Espaçamento maior após o ícone

              // Nome do plano e estatísticas
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    plan.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700, // Mais destaque para o nome do plano
                          color: Theme.of(context).colorScheme.onSurface, // Cor mais escura para o texto principal
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (plan.banca != null && plan.banca!.isNotEmpty) // Exibe a banca se disponível
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0), // Espaçamento superior para a banca
                      child: Text(
                        plan.banca!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.primary), // Estilo para a banca
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 8), // Espaçamento entre nome/banca e estatísticas
                  Text(
                    'Disciplinas: ${stats.subjectCount}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]), // Estilo discreto
                  ),
                  Text(
                    'Tópicos: ${stats.topicCount}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]), // Estilo discreto
                  ),
                ],
              ),
              // Botão de exclusão
              Align(
                alignment: Alignment.bottomRight,
                child: IconButton(
                  icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error), // Ícone de exclusão com cor de erro
                  onPressed: () {
                    _showDeleteConfirmationDialog(context, plan);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, Plan plan) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationModal(
          title: 'Excluir Plano',
          message: 'Você tem certeza que deseja excluir o plano "${plan.name}"? Esta ação não pode ser desfeita.',
          confirmText: 'Excluir',
          onConfirm: () {
            Provider.of<PlansProvider>(context, listen: false).deletePlan(plan.id);
            Navigator.of(context).pop();
          },
          onClose: () => Navigator.of(context).pop(),
        );
      },
    );
  }


  // Função auxiliar para calcular o número total de tópicos (replicando a lógica do desktop)
  int _calculateTotalTopicsRecursively(List<Topic> topics) {
    if (topics.isEmpty) {
      return 0;
    }
    return topics.fold<int>(0, (previousValue, topic) {
      return previousValue + 1 + _calculateTotalTopicsRecursively(topic.sub_topics ?? []);
    });
  }

}
