import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:ouroboros_mobile/models/data_models.dart';

class ScrapingService {
  final Completer<Plan> _completer = Completer<Plan>();
  late HeadlessInAppWebView _headlessWebView;
  late String _initialUrl;

  Map<String, dynamic> _headerData = {};
  List<Map<String, String>> _subjectLinks = [];
  List<Subject> _finalSubjects = [];
  int _subjectIndex = 0;
  int _tempIdCounter = -1;

  Future<Plan> scrapeGuide(String url) {
    _initialUrl = url;
    _headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      onWebViewCreated: (controller) {
        // debugPrint('ScrapingService: HeadlessInAppWebView criado!');
      },
      onLoadStart: (controller, url) {
        // debugPrint('ScrapingService: Iniciando carregamento de: $url');
      },
      onLoadStop: _onPageLoaded,
      onReceivedError: (controller, url, error) {
        debugPrint('ScrapingService: Erro ao carregar $url: Código ${error.type}, Mensagem: ${error.description}');
        _completer.completeError(
          'Erro ao carregar a página: ${error.description}',
        );
      },
      onConsoleMessage: (controller, consoleMessage) {
        // debugPrint('ScrapingService: WebView Console [${consoleMessage.messageLevel.toString().split('.').last}]: ${consoleMessage.message}');
      },
      onProgressChanged: (controller, progress) {
        // debugPrint('ScrapingService: Progresso de carregamento: $progress%');
      },
    );

    _headlessWebView.run();
    return _completer.future;
  }

  Future<void> _onPageLoaded(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    if (url == null) return;

    try {
      if (url.toString() == _initialUrl) {
        await _extractHeaderAndSubjectLinks(controller);
        await _scrapeNextSubject(controller);
      } else {
        await _extractTopics(controller);
        await _scrapeNextSubject(controller);
      }
    } catch (e) {
      _completer.completeError(e);
    }
  }

  Future<void> _extractHeaderAndSubjectLinks(
    InAppWebViewController controller,
  ) async {
    await _waitForSelector(
      controller,
      'div.guias-cabecalho, div.cadernos-agrupamento, div.detalhes-cabecalho',
    );

    final String getHeaderJs = """
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
    final headerResult = await controller.evaluateJavascript(source: getHeaderJs);
    _headerData = Map<String, dynamic>.from(headerResult as Map<dynamic, dynamic>);

    final String getLinksJs = """
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
    final linksResult = await controller.evaluateJavascript(source: getLinksJs);
    final linksList = linksResult as List<dynamic>;
    _subjectLinks = linksList
        .map((item) => Map<String, String>.from(item as Map<dynamic, dynamic>))
        .toList();
  }

  Future<void> _scrapeNextSubject(InAppWebViewController controller) async {
    if (_subjectIndex < _subjectLinks.length) {
      final subjectLink = _subjectLinks[_subjectIndex];
      _subjectIndex++;
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri(subjectLink['url']!)),
      );
    } else {
      _finishScraping();
    }
  }

  Future<void> _extractTopics(InAppWebViewController controller) async {
    await _waitForSelector(
      controller,
      'div.caderno-guia-arvore-indice ul, div.guia-arvore-indice ul',
      timeout: 60000,
    );

    await Future.delayed(const Duration(milliseconds: 3000));

    final String getTopicsJs = """
    (function() {
      const processLevel = (ul) => {
        if (!ul) return [];
        const items = [];

        const directLis = ul.querySelectorAll(':scope > li');
        directLis.forEach(li => {
          const span = li.querySelector(':scope > span:not(.capitulo-questoes)');
          const text = span?.textContent?.trim() || 'Tópico sem nome';
          const questionCount = 0;

          const subUl = li.querySelector(':scope > ul');
          const subTopics = subUl ? processLevel(subUl) : [];

          items.push({
            topic_text: text,
            question_count: questionCount,
            sub_topics: subTopics,
            is_grouping_topic: subTopics.length > 0
          });
        });

        return items;
      };

      const root = document.querySelector('div.caderno-guia-arvore-indice ul, div.guia-arvore-indice ul, ul.arvore-indice');
      if (!root) {
        return [];
      }

      const result = processLevel(root);
      return result;
    })();
  """;

    dynamic topicsResult;
    try {
      topicsResult = await controller.evaluateJavascript(source: getTopicsJs);
    } catch (e) {
      debugPrint('Erro ao executar JS de extração de tópicos: $e');
      topicsResult = [];
    }

    if (topicsResult == null || (topicsResult is List && topicsResult.isEmpty)) {
      debugPrint('AVISO: Nenhum tópico extraído para a matéria: ${_subjectLinks[_subjectIndex - 1]['name']}');
      topicsResult = [];
    }

    List<Topic> flattenTopics(List<dynamic> nodes, {int? parentId}) {
      List<Topic> list = [];

      for (final node in nodes) {
        final map = Map<String, dynamic>.from(node as Map<dynamic, dynamic>);
        final topicId = _tempIdCounter--;
        final topic = Topic(
          id: topicId,
          subject_id: '',
          topic_text: map['topic_text'] as String? ?? 'Sem nome',
          parent_id: parentId,
          question_count: (map['question_count'] as num?)?.toInt() ?? 0,
          is_grouping_topic: map['is_grouping_topic'] == true,
          userWeight: null,
          lastModified: DateTime.now().millisecondsSinceEpoch,
        );

        list.add(topic);

        if (map['sub_topics'] is List && (map['sub_topics'] as List).isNotEmpty) {
          list.addAll(flattenTopics(map['sub_topics'] as List<dynamic>, parentId: topic.id));
        }
      }
      return list;
    }

    final List<Topic> allTopics = flattenTopics(topicsResult as List<dynamic>);

    final subject = Subject(
      id: (_tempIdCounter--).toString(),
      plan_id: '',
      subject: _subjectLinks[_subjectIndex - 1]['name']!,
      color: '#ef4444',
      topics: allTopics,
      total_topics_count: allTopics.length,
      lastModified: DateTime.now().millisecondsSinceEpoch,
    );

    _finalSubjects.add(subject);
  }

  void _finishScraping() {
    final planId = (_tempIdCounter--).toString();
    final now = DateTime.now().millisecondsSinceEpoch;

    final subjectsWithPlanId = _finalSubjects.map((s) {
      final subjectId = s.id;
      final topicsWithSubjectId = s.topics
          .map((t) => t.copyWith(subject_id: subjectId))
          .toList();

      return s.copyWith(
        plan_id: planId,
        topics: topicsWithSubjectId,
        lastModified: now,
      );
    }).toList();

    final plan = Plan(
      id: planId,
      name: _headerData['name'] as String? ?? '',
      cargo: _headerData['cargo'] as String?,
      edital: _headerData['edital'] as String?,
      banca: _headerData['banca'] as String?,
      iconUrl: _headerData['iconUrl'] as String?,
      subjects: subjectsWithPlanId,
      lastModified: now,
    );
    _completer.complete(plan);
    _headlessWebView.dispose();
  }

  Future<void> _waitForSelector(
    InAppWebViewController controller,
    String selector, {
    int timeout = 30000,
  }) async {
    final completer = Completer<void>();
    final stopwatch = Stopwatch()..start();

    Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      final result = await controller.evaluateJavascript(
        source: 'document.querySelector("$selector") != null',
      );
      if (result == true) {
        timer.cancel();
        completer.complete();
      } else if (stopwatch.elapsedMilliseconds > timeout) {
        timer.cancel();
        completer.completeError(
          Exception('Timeout esperando pelo seletor: $selector'),
        );
      }
    });

    return completer.future;
  }
}
