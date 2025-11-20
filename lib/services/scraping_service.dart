import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:uuid/uuid.dart';

class ScrapingService {
  final Completer<Plan> _completer = Completer<Plan>();
  late HeadlessInAppWebView _headlessWebView;
  late String _initialUrl;

  // Armazenamento temporário dos dados
  Map<String, dynamic> _headerData = {};
  List<Map<String, String>> _subjectLinks = [];
  List<Subject> _finalSubjects = [];
  int _subjectIndex = 0;

  Future<Plan> scrapeGuide(String url) {
    _initialUrl = url;
    _headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      onWebViewCreated: (controller) {
        print('HeadlessInAppWebView criado!');
      },
      onLoadStop: _onPageLoaded,
      onLoadError: (controller, url, code, message) {
        _completer.completeError('Erro ao carregar a página: $message');
      },
    );

    _headlessWebView.run();
    return _completer.future;
  }

  Future<void> _onPageLoaded(InAppWebViewController controller, WebUri? url) async {
    if (url == null) return;

    try {
      // Se for a página inicial, extraia o cabeçalho e os links das matérias
      if (url.toString() == _initialUrl) {
        await _extractHeaderAndSubjectLinks(controller);
        // Inicia o processo de scraping das matérias
        await _scrapeNextSubject(controller);
      } else {
        // Se for uma página de matéria, extraia os tópicos
        await _extractTopics(controller);
        // Passa para a próxima matéria
        await _scrapeNextSubject(controller);
      }
    } catch (e) {
      _completer.completeError(e);
    }
  }

  Future<void> _extractHeaderAndSubjectLinks(InAppWebViewController controller) async {
    // Aguarda o seletor principal estar presente
    await _waitForSelector(controller, 'div.guias-cabecalho, div.cadernos-agrupamento, div.detalhes-cabecalho');

    // Extrai os dados do cabeçalho
    String getHeaderJs = """
      (function() {
        let name = document.querySelector('div.guias-cabecalho-concurso-nome')?.textContent?.trim() || 
                   document.querySelector('div.detalhes-cabecalho-informacoes-texto h1 span:not([class])')?.textContent?.trim() || 
                   document.title.split('-')[0].trim();
        let cargo = document.querySelector('div.guias-cabecalho-concurso-cargo')?.textContent?.trim() || 
                    document.querySelector('div.detalhes-cabecalho-informacoes-orgao')?.textContent?.trim() || '';
        let edital = document.querySelector('div.guias-cabecalho-concurso-edital')?.textContent?.trim() || '';
        let iconUrl = document.querySelector('div.guias-cabecalho-logo img')?.getAttribute('src') || 
                      document.querySelector('div.detalhes-cabecalho-logotipo img')?.getAttribute('src') || 
                      document.querySelector('img[alt*="logotipo"]')?.getAttribute('src') || '';
        let banca = '';
        const bancaLabel = Array.from(document.querySelectorAll('span.detalhes-campos')).find(el => el.textContent?.trim() === 'Banca');
        if (bancaLabel && bancaLabel.nextElementSibling) {
            banca = (bancaLabel.nextElementSibling).textContent?.split('(')[0].trim() || '';
        }
        return { name, cargo, edital, iconUrl, banca };
      })();
    """;
    _headerData = await controller.evaluateJavascript(source: getHeaderJs) as Map<String, dynamic>;

    // Extrai os links das matérias
    String getLinksJs = """
      (function() {
        const links = [];
        let subjectElements = document.querySelectorAll('div.guia-materia-item');
        if (subjectElements.length > 0) {
            subjectElements.forEach(el => {
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
            subjectElements = document.querySelectorAll('div.cadernos-item');
            subjectElements.forEach(el => {
                const nameEl = el.querySelector('span.cadernos-colunas-destaque');
                const anchor = el.querySelector('a.cadernos-ver-detalhes');
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
    _subjectLinks = linksResult.map((item) => Map<String, String>.from(item)).toList();
  }

  Future<void> _scrapeNextSubject(InAppWebViewController controller) async {
    if (_subjectIndex < _subjectLinks.length) {
      final subjectLink = _subjectLinks[_subjectIndex];
      _subjectIndex++;
      await controller.loadUrl(urlRequest: URLRequest(url: WebUri(subjectLink['url']!)));
    } else {
      // Processo finalizado
      _finishScraping();
    }
  }

  Future<void> _extractTopics(InAppWebViewController controller) async {
    await _waitForSelector(controller, 'div.caderno-guia-arvore-indice ul');

    String getTopicsJs = """
      (function() {
        const processLis = (ulElement) => {
            const topics = [];
            if (!ulElement) return topics;
            Array.from(ulElement.children).forEach(child => {
                if (child.tagName !== 'LI') return;
                const span = child.querySelector(':scope > span');
                const topicText = span?.textContent?.trim();
                if (!topicText) return;

                const questionCountEl = child.querySelector('span.capitulo-questoes > span');
                let questionCount = 0;
                if (questionCountEl) {
                    const text = questionCountEl.textContent?.trim().toLowerCase();
                    if (text === 'uma questão') questionCount = 1;
                    else if (text) {
                        const match = text.match(/(\d+)/);
                        if (match) questionCount = parseInt(match[1], 10);
                    }
                }

                const subUl = child.nextElementSibling;
                const sub_topics = (subUl && subUl.tagName === 'UL') ? processLis(subUl) : [];
                
                topics.push({ 
                    topic_text: topicText, 
                    sub_topics: sub_topics, 
                    question_count: questionCount, 
                    is_grouping_topic: sub_topics.length > 0 
                });
            });
            return topics;
        };
        const mainTreeContainer = document.querySelector('div.caderno-guia-arvore-indice ul');
        return processLis(mainTreeContainer);
      })();
    """;

    final topicsResult = await controller.evaluateJavascript(source: getTopicsJs) as List<dynamic>;

    print('ScrapingService: Raw topicsResult for subject ${_subjectLinks[_subjectIndex - 1]['name']}: $topicsResult');
    if (topicsResult.isEmpty) {
      print('ScrapingService: WARNING - topicsResult is empty for subject ${_subjectLinks[_subjectIndex - 1]['name']}');
    }

    final subjectLink = _subjectLinks[_subjectIndex - 1];
    final List<Topic> topics = topicsResult.map((topicMap) => Topic.fromMap(topicMap)).toList();

    _finalSubjects.add(Subject(
      id: const Uuid().v4(),
      plan_id: '', // Será preenchido depois
      subject: subjectLink['name']!,
      color: '#ef4444', // Cor placeholder
      topics: topics,
      total_topics_count: topics.length, // Simplificado, a lógica de contagem recursiva pode ser adicionada depois
    ));
  }

  void _finishScraping() {
    final planId = const Uuid().v4();

    // Atribuir o plan_id correto a cada matéria
    final subjectsWithPlanId = _finalSubjects.map((s) => Subject(
      id: s.id,
      plan_id: planId,
      subject: s.subject,
      color: s.color,
      topics: s.topics,
      total_topics_count: s.total_topics_count,
    )).toList();

    final plan = Plan(
      id: planId,
      name: _headerData['name'] ?? '',
      cargo: _headerData['cargo'],
      edital: _headerData['edital'],
      banca: _headerData['banca'],
      iconUrl: _headerData['iconUrl'],
      subjects: subjectsWithPlanId,
    );
    _completer.complete(plan);
    _headlessWebView.dispose();
  }

  Future<void> _waitForSelector(InAppWebViewController controller, String selector, {int timeout = 30000}) async {
    final completer = Completer<void>();
    final stopwatch = Stopwatch()..start();

    Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      final result = await controller.evaluateJavascript(source: 'document.querySelector("$selector") != null');
      if (result == true) {
        timer.cancel();
        completer.complete();
      } else if (stopwatch.elapsedMilliseconds > timeout) {
        timer.cancel();
        completer.completeError(Exception('Timeout esperando pelo seletor: $selector'));
      }
    });

    return completer.future;
  }
}