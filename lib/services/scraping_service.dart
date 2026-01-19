import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:ouroboros_mobile/models/data_models.dart';

class ScrapingService {
  final Completer<Plan> _completer = Completer<Plan>();
  late HeadlessInAppWebView _headlessWebView;
  late String _initialUrl;

  // Armazenamento temporário dos dados
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
        // print('ScrapingService: HeadlessInAppWebView criado!');
      },
      onLoadStart: (controller, url) {
        // print('ScrapingService: Iniciando carregamento de: $url');
      },
      onLoadStop: _onPageLoaded,
      onReceivedError: (controller, url, error) {
        // print('ScrapingService: Erro ao carregar $url: Código ${error.type}, Mensagem: ${error.description}');
        _completer.completeError(
          'Erro ao carregar a página: ${error.description}',
        );
      },
      onConsoleMessage: (controller, consoleMessage) {
        // print('ScrapingService: WebView Console [${consoleMessage.messageLevel.toString().split('.').last}]: ${consoleMessage.message}');
      },
      onProgressChanged: (controller, progress) {
        // print('ScrapingService: Progresso de carregamento: $progress%');
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

  Future<void> _extractHeaderAndSubjectLinks(
    InAppWebViewController controller,
  ) async {
    // Aguarda o seletor principal estar presente
    await _waitForSelector(
      controller,
      'div.guias-cabecalho, div.cadernos-agrupamento, div.detalhes-cabecalho',
    );

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
    _headerData =
        await controller.evaluateJavascript(source: getHeaderJs)
            as Map<String, dynamic>;

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
    final linksResult =
        await controller.evaluateJavascript(source: getLinksJs)
            as List<dynamic>;
    _subjectLinks = linksResult
        .map((item) => Map<String, String>.from(item))
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
      // Processo finalizado
      _finishScraping();
    }
  }

  Future<void> _extractTopics(InAppWebViewController controller) async {
    // Aguarda a árvore aparecer
    await _waitForSelector(
      controller,
      'div.caderno-guia-arvore-indice ul, div.guia-arvore-indice ul',
      timeout: 60000,
    );

    // Delay crítico: muitos sites (especialmente Estratégia) carregam os números via AJAX depois
    await Future.delayed(const Duration(milliseconds: 3000));

    final String getTopicsJs = """
    (function() {
      const processLevel = (ul) => {
        if (!ul) return [];
        const items = [];

        const directLis = ul.querySelectorAll(':scope > li');
        directLis.forEach(li => {
          // Nome do tópico
          const span = li.querySelector(':scope > span:not(.capitulo-questoes)');
          const text = span?.textContent?.trim() || 'Tópico sem nome';
          
          // Defina a contagem de perguntas como 0, conforme solicitado
          const questionCount = 0;

          // Subtópicos
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
        // console.log('Árvore de tópicos NÃO encontrada!');
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
      // print('Erro ao executar JS de extração de tópicos: $e');
      topicsResult = [];
    }

    if (topicsResult == null ||
        (topicsResult is List && topicsResult.isEmpty)) {
      // print('AVISO: Nenhum tópico extraído para a matéria: ${_subjectLinks[_subjectIndex - 1]['name']}');
      topicsResult = [];
    }

    List<Topic> flattenTopics(List<dynamic> nodes, {int? parentId}) {
      List<Topic> list = [];

      for (var node in nodes) {
        final map = Map<String, dynamic>.from(node);
        final topicId = _tempIdCounter--;
        final topic = Topic(
          id: topicId,
          subject_id: '', // será preenchido depois
          topic_text: map['topic_text'] ?? 'Sem nome',
          parent_id: parentId,
          question_count: (map['question_count'] as num?)?.toInt() ?? 0,
          is_grouping_topic: map['is_grouping_topic'] == true,
          userWeight: null,
          lastModified: DateTime.now().millisecondsSinceEpoch,
        );

        list.add(topic);

        if (map['sub_topics'] is List &&
            (map['sub_topics'] as List).isNotEmpty) {
          list.addAll(flattenTopics(map['sub_topics'], parentId: topic.id));
        }
      }
      return list;
    }

    final List<Topic> allTopics = flattenTopics(topicsResult);

    // print("MATÉRIA: ${_subjectLinks[_subjectIndex - 1]['name']} → ${allTopics.length} tópicos salvos (com subtópicos)");

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
      name: _headerData['name'] ?? '',
      cargo: _headerData['cargo'],
      edital: _headerData['edital'],
      banca: _headerData['banca'],
      iconUrl: _headerData['iconUrl'],
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
