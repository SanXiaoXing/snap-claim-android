/* ==========================================================================
 * SnapClaim 下载页脚本
 *
 * 设计原则：
 * 1. 数据来自 GitHub Releases API（版本号、包大小、下载量、更新说明都自动跟新版本走），
 *    但 **API 不可用时必须能降级**：网络受限或限流时用内置的兜底数据继续渲染，
 *    绝不允许出现「按钮点不动」的下载页。
 * 2. 不引入构建步骤，纯静态资源；二维码库本地内置（vendor/qrcode.js，MIT）。
 * ========================================================================== */

(function () {
  'use strict';

  /* ------------------------------- 配置 ------------------------------- */

  var REPO = 'SanXiaoXing/snap-claim-android';
  var API = 'https://api.github.com/repos/' + REPO;
  var REPO_URL = 'https://github.com/' + REPO;
  var RELEASES_URL = REPO_URL + '/releases';
  var CACHE_KEY = 'snapclaim:releases:v1';
  var CACHE_TTL = 30 * 60 * 1000; // 30 分钟：GitHub 匿名接口每小时只有 60 次，别浪费
  var FETCH_TIMEOUT = 9000;

  /* ABI 元信息：数组顺序即推荐优先级，match 用来认 GitHub 上的包名 */
  var ABIS = [
    {
      key: 'arm64-v8a',
      icon: '📱',
      note: '绝大多数安卓手机（近几年机型都选它）',
      recommended: true,
      match: /arm64-?v8a/i,
    },
    {
      key: 'armeabi-v7a',
      icon: '🧓',
      note: '32 位老机型、老旧平板',
      match: /armeabi-?v7a|armv7/i,
    },
    {
      key: 'x86_64',
      icon: '💻',
      note: '安卓模拟器，少量平板',
      match: /x86[-_]?64/i,
    },
  ];

  /* 渲染兜底数据：以当前最新版 v1.5.0 为准（数值取自 GitHub Release 资产列表）。
     GitHub 接口在某些网络下会 403 / 超时，这份数据保证页面永远可用。 */
  var FALLBACK = {
    tag: 'v1.5.0',
    publishedAt: '2026-09-01T15:37:10Z',
    assets: [
      {
        name: 'SnapClaim_1.5.0_arm64-v8a.apk',
        sizeHuman: '40.2 MB',
        digest: 'sha256:9fa3f386a6f357f735dcd33882770ad1cf574792283bd2547da6f4d82f664f95',
        download_count: null,
      },
      {
        name: 'SnapClaim_1.5.0_armeabi-v7a.apk',
        sizeHuman: '32 MB',
        digest: 'sha256:a5f7c616bae187f9ebdc99956a85a8e1455a7e40b455210e5c46192aa8e9da69',
        download_count: null,
      },
      {
        name: 'SnapClaim_1.5.0_x86_64.apk',
        sizeHuman: '43.1 MB',
        digest: 'sha256:81d094fd8f96bf9a1a56775aab579dd229d3dbe829440b78a9cdd297eb134417',
        download_count: null,
      },
    ],
  };

  /* 内置的更新说明（仅当接口拿不到时展示，内容摘自仓库 RELEASELOG.md） */
  var FALLBACK_NOTES = [
    {
      tag: 'v1.5.0',
      publishedAt: '2026-09-01T15:37:10Z',
      body: [
        '# Snap Claim for Android v1.5.0 🧹✨',
        '',
        '## 🔧 代码精简优化',
        '',
        '本次版本没有新功能，专注内部代码精简：',
        '',
        '- 差补计算移除 Rust 桥，改为本地同步计算',
        '- 统一 10 处弹窗样式为公共 `AppDialog` 组件',
        '- 删除重复的明细行 / 日期胶囊 / 按压反馈等冗余实现',
        '- 统计口径统一复用报销汇总的样式与聚合来源',
        '- 版本号单一来源，应用内显示与备份 manifest 不再各自硬编码',
      ].join('\n'),
    },
    {
      tag: 'v1.4.2',
      publishedAt: '2026-08-28T08:02:00Z',
      body: [
        '# Snap Claim for Android v1.4.2 📊✨',
        '',
        '统计页月度分布改为按退补金额统计，与页面累计金额口径保持一致。',
        '',
        '- 📊 月度分布统计口径修正',
        '- ✅ 累计金额与月度分布展示口径统一',
        '- 🗂️ 分类 / 月度占比展示更准确',
      ].join('\n'),
    },
    {
      tag: 'v1.4.1',
      publishedAt: '2026-08-14T07:23:00Z',
      body: [
        '# Snap Claim for Android v1.4.1 📅✨',
        '',
        '> 出差日期合并成一个范围胶囊，一次弹出日历同时选起止日期。',
        '',
        '- 📅 日期范围选择：点一次同时选齐起止日期',
        '- 🧹 回归系统原生日历样式，观感更清爽',
        '- 🔄 名称未手动修改时自动跟随新的日期范围，差补实时重算',
      ].join('\n'),
    },
  ];

  /* ---------------------------- 小工具函数 ---------------------------- */

  function $(sel, root) {
    return (root || document).querySelector(sel);
  }

  function escapeHtml(str) {
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function formatBytes(bytes) {
    if (typeof bytes !== 'number' || !isFinite(bytes) || bytes <= 0) return '';
    var mb = bytes / 1024 / 1024;
    if (mb >= 1) return mb.toFixed(1) + ' MB';
    return Math.max(1, Math.round(bytes / 1024)) + ' KB';
  }

  function formatDate(iso) {
    if (!iso) return '';
    var d = new Date(iso);
    if (isNaN(d.getTime())) return '';
    var pad = function (n) {
      return n < 10 ? '0' + n : String(n);
    };
    return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate());
  }

  function toast(msg) {
    var el = $('#toast');
    if (!el) return;
    el.textContent = msg;
    el.classList.add('is-visible');
    clearTimeout(toast._timer);
    toast._timer = setTimeout(function () {
      el.classList.remove('is-visible');
    }, 1800);
  }

  /* ------------------------------- 主题 ------------------------------- */

  function initTheme() {
    var saved = null;
    try {
      saved = localStorage.getItem('snapclaim:theme');
    } catch (e) {
      /* 隐私模式下 localStorage 可能不可用，忽略即可 */
    }
    var prefersDark =
      window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
    applyTheme(saved || (prefersDark ? 'dark' : 'light'));

    var toggle = $('#theme-toggle');
    if (toggle) {
      toggle.addEventListener('click', function () {
        var next =
          document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
        applyTheme(next);
        try {
          localStorage.setItem('snapclaim:theme', next);
        } catch (e) {
          /* 存不了就只在本次会话生效 */
        }
      });
    }
  }

  function applyTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    var meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', theme === 'dark' ? '#141210' : '#ffffff');
  }

  /* ------------------------------ 导航交互 ------------------------------ */

  function initNav() {
    var nav = $('#nav');
    var toTop = $('#to-top');

    function onScroll() {
      var y = window.scrollY || document.documentElement.scrollTop;
      if (nav) nav.classList.toggle('is-scrolled', y > 8);
      if (toTop) toTop.classList.toggle('is-visible', y > 700);
    }

    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();

    if (toTop) {
      toTop.addEventListener('click', function () {
        window.scrollTo({ top: 0, behavior: 'smooth' });
      });
    }

    // 导航高亮：用 IntersectionObserver 盯住各分节，避免手写滚动计算
    var links = Array.prototype.slice.call(document.querySelectorAll('.nav__link[href^="#"]'));
    var sections = links
      .map(function (a) {
        return document.querySelector(a.getAttribute('href'));
      })
      .filter(Boolean);

    if (!sections.length || !('IntersectionObserver' in window)) return;

    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          links.forEach(function (a) {
            a.classList.toggle(
              'is-active',
              a.getAttribute('href') === '#' + entry.target.id
            );
          });
        });
      },
      { rootMargin: '-45% 0px -50% 0px' }
    );
    sections.forEach(function (s) {
      observer.observe(s);
    });
  }

  /* ------------------------------ 入场动画 ------------------------------ */

  function initReveal() {
    var items = Array.prototype.slice.call(document.querySelectorAll('.reveal'));

    function showAll() {
      items.forEach(function (el) {
        el.classList.add('is-in');
      });
    }

    var reduce =
      window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduce || !('IntersectionObserver' in window)) {
      showAll();
      return;
    }

    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add('is-in');
            observer.unobserve(entry.target);
          }
        });
      },
      { rootMargin: '0px 0px -8% 0px', threshold: 0.06 }
    );
    items.forEach(function (el) {
      observer.observe(el);
    });

    // 兜底：万一观察回调没被触发（深链直接跳到某一段、或极端渲染时序），
    // 也不能让内容永远停在 opacity:0 —— 到点强行走一遍。
    setTimeout(showAll, 1600);
  }

  /* ---------------------------- 数据获取 ---------------------------- */

  function readCache() {
    try {
      var raw = sessionStorage.getItem(CACHE_KEY);
      if (!raw) return null;
      var parsed = JSON.parse(raw);
      if (!parsed || Date.now() - parsed.ts > CACHE_TTL) return null;
      return parsed.data;
    } catch (e) {
      return null;
    }
  }

  function writeCache(data) {
    try {
      sessionStorage.setItem(CACHE_KEY, JSON.stringify({ ts: Date.now(), data: data }));
    } catch (e) {
      /* 缓存写不进去不影响展示 */
    }
  }

  function fetchJson(url) {
    // AbortController 兜住「请求挂住不返回」的情况，否则页面会一直停在加载态
    var controller = 'AbortController' in window ? new AbortController() : null;
    var timer = controller
      ? setTimeout(function () {
          controller.abort();
        }, FETCH_TIMEOUT)
      : null;

    return fetch(url, {
      headers: { Accept: 'application/vnd.github+json' },
      signal: controller ? controller.signal : undefined,
    })
      .then(function (res) {
        if (!res.ok) throw new Error('HTTP ' + res.status);
        return res.json();
      })
      .finally(function () {
        if (timer) clearTimeout(timer);
      });
  }

  /**
   * 拉取发布数据。
   * 返回 { releases: [...], live: Boolean }；live 为 false 表示用了内置兜底数据。
   */
  function loadReleases() {
    var cached = readCache();
    if (cached) return Promise.resolve(cached);

    return fetchJson(API + '/releases?per_page=12')
      .then(function (list) {
        if (!Array.isArray(list) || !list.length) throw new Error('empty');
        var data = { releases: list, live: true };
        writeCache(data);
        return data;
      })
      .catch(function (err) {
        console.warn('[SnapClaim] 无法读取 GitHub 发布数据，改用内置数据：', err.message);
        return { releases: [], live: false };
      });
  }

  /* ---------------------------- 渲染：下载区 ---------------------------- */

  function normalizeRelease(release) {
    var assets = (release && release.assets) || [];
    var abis = ABIS.map(function (abi) {
      var asset = null;
      for (var i = 0; i < assets.length; i++) {
        if (abi.match.test(assets[i].name)) {
          asset = assets[i];
          break;
        }
      }
      return {
        meta: abi,
        name: asset ? asset.name : null,
        url: asset ? asset.browser_download_url : null,
        size: asset && typeof asset.size === 'number' ? asset.size : null,
        sizeHuman: asset && asset.sizeHuman ? asset.sizeHuman : '',
        digest: asset && asset.digest ? asset.digest : '',
        downloads: asset && typeof asset.download_count === 'number' ? asset.download_count : null,
      };
    });

    // arm64 缺失时，退而求其次用第一个能拿到的包当主下载（保证按钮一定可用）
    var primary = null;
    for (var i = 0; i < abis.length; i++) {
      if (abis[i].url) {
        primary = abis[i];
        break;
      }
    }

    return {
      tag: release && release.tag_name ? release.tag_name : FALLBACK.tag,
      publishedAt: release && release.published_at ? release.published_at : FALLBACK.publishedAt,
      body: release && release.body ? release.body : '',
      assets: assets,
      abis: abis,
      primary: primary,
      totalDownloads: assets.reduce(function (sum, a) {
        return sum + (typeof a.download_count === 'number' ? a.download_count : 0);
      }, 0),
      hasCounts: assets.some(function (a) {
        return typeof a.download_count === 'number';
      }),
    };
  }

  function renderDownload(release) {
    var tag = release.tag;
    var date = formatDate(release.publishedAt);

    setText('#hero-version', tag);
    setText('#hero-date', date ? '发布于 ' + date : '');
    setText('#dl-version', tag);
    setText('#dl-date', date);

    var primary = release.primary;
    var btn = $('#btn-primary');
    if (btn && primary) {
      btn.href = primary.url;
      var sizeText = primary.size ? formatBytes(primary.size) : primary.sizeHuman;
      setText('#primary-sub', primary.name + (sizeText ? ' · ' + sizeText : ''));
    }

    // ABI 列表：主按钮已经是 arm64 时，这里只列其余架构，避免重复入口
    var list = $('#abi-list');
    if (list) {
      var rest = release.abis.filter(function (item) {
        return item.url && (!primary || item.name !== primary.name);
      });
      list.innerHTML = rest
        .map(function (item) {
          var sizeText = item.size ? formatBytes(item.size) : item.sizeHuman;
          return [
            '<a class="abi" href="' + escapeHtml(item.url) + '" rel="noopener">',
            '<span class="abi__icon">' + item.meta.icon + '</span>',
            '<span class="abi__text">',
            '<span class="abi__name">' + escapeHtml(item.meta.key) + '</span>',
            '<span class="abi__note">' + escapeHtml(item.meta.note) + '</span>',
            '</span>',
            '<span class="abi__right">',
            '<span class="abi__size">' + escapeHtml(sizeText || '—') + '</span>',
            '<span class="abi__dl">' + downloadText(item.downloads) + '</span>',
            '</span>',
            '</a>',
          ].join('');
        })
        .join('');

      if (!rest.length) {
        list.innerHTML = '';
      }
    }

    // 下载完整表格（含主包，方便对照架构与大小）
    var tbody = $('#dl-table-body');
    if (tbody) {
      tbody.innerHTML = release.abis
        .map(function (item) {
          var sizeText = item.size ? formatBytes(item.size) : item.sizeHuman;
          if (!item.url) {
            return (
              '<tr><td><span class="mono">' +
              escapeHtml(item.meta.key) +
              '</span></td><td class="muted">这一版没有提供</td><td class="num">—</td><td></td></tr>'
            );
          }
          return [
            '<tr>',
            '<td><span class="mono">' + escapeHtml(item.meta.key) + '</span>',
            item.meta.recommended
              ? ' <span class="chip chip--accent">推荐</span>'
              : '',
            '</td>',
            '<td class="muted">' + escapeHtml(sizeText || '—') + '</td>',
            '<td class="num muted">' +
              (typeof item.downloads === 'number' && item.downloads > 0
                ? downloadText(item.downloads)
                : '—') +
              '</td>',
            '<td class="num"><a class="link-plain" href="' +
              escapeHtml(item.url) +
              '" rel="noopener">下载</a></td>',
            '</tr>',
          ].join('');
        })
        .join('');
    }

    // 校验信息：优先 sha256（GitHub 新版本才带 digest），退回到「去 Release 页核对」
    var primaryDigest = (primary && primary.digest) || '';
    var sha = primaryDigest.replace(/^sha256:/i, '');
    if (!sha) {
      var fallbackAsset = FALLBACK.assets.filter(function (a) {
        return primary && a.name === primary.name;
      })[0];
      sha = fallbackAsset ? fallbackAsset.digest.replace(/^sha256:/i, '') : '';
    }
    var shaRow = $('#sha-row');
    if (shaRow && sha) {
      shaRow.hidden = false;
      setText('#sha-value', sha);
      var copyBtn = $('#sha-copy');
      if (copyBtn) {
        copyBtn.addEventListener('click', function () {
          copyText(sha, 'SHA-256 已复制');
        });
      }
    }

    var totalNote = $('#dl-total');
    if (totalNote && release.hasCounts && release.totalDownloads > 0) {
      totalNote.hidden = false;
      totalNote.textContent = '累计下载 ' + release.totalDownloads + ' 次';
    }

    renderQr(primary ? primary.url : RELEASES_URL);
  }

  function downloadText(count) {
    return typeof count === 'number' && count > 0
      ? '下载 ' + count + ' 次'
      : '';
  }

  function setText(sel, text) {
    var el = $(sel);
    if (el) el.textContent = text || '';
  }

  /* ----------------------------- 渲染：二维码 ----------------------------- */

  // 用本地内置的 qrcode-generator（MIT，见 vendor/）把下载地址画成 SVG。
  // 放本地而不是调外部二维码接口：内网 / 弱网下也能扫，且不泄露访问行为给第三方。
  function renderQr(url) {
    var box = $('#qr-code');
    if (!box || typeof window.qrcode !== 'function') return;
    try {
      var qr = window.qrcode(0, 'M');
      qr.addData(url);
      qr.make();
      box.innerHTML = qr.createSvgTag({ cellSize: 4, margin: 1, scalable: true });
    } catch (e) {
      console.warn('[SnapClaim] 二维码生成失败：', e);
      box.innerHTML = '';
      var tip = $('#qr-tip');
      if (tip) tip.textContent = '二维码生成失败，请用上面的按钮下载';
    }
  }

  /* --------------------------- 渲染：更新日志 --------------------------- */

  function renderChangelog(data) {
    var timeline = $('#timeline');
    if (!timeline) return;

    var releases = (data.releases || []).map(function (r) {
      return {
        tag: r.tag_name,
        publishedAt: r.published_at,
        body: r.body || '',
        url: r.html_url,
        prerelease: !!r.prerelease,
        draft: !!r.draft,
      };
    });

    var live = data.live && releases.length;
    if (!live) releases = FALLBACK_NOTES;

    timeline.innerHTML = releases
      .slice(0, 8)
      .map(function (r, index) {
        var body = markdownToHtml(r.body || '');
        return [
          '<details class="release"',
          index === 0 ? ' open' : '',
          '>',
          '<summary class="release__head">',
          '<span class="release__ver">' + escapeHtml(r.tag) + '</span>',
          '<span class="release__date">' + escapeHtml(formatDate(r.publishedAt)) + '</span>',
          '<span class="release__sum">' + escapeHtml(summarize(r.body)) + '</span>',
          '<span class="release__caret">' + caretSvg() + '</span>',
          '</summary>',
          '<div class="release__body">' + body + '</div>',
          '</details>',
        ].join('');
      })
      .join('');

    // 数据来源提示：接口拿不到时明确告诉用户，并给一个重试入口
    var note = $('#source-note');
    if (note) {
      if (live) {
        note.innerHTML =
          '数据来自 GitHub Releases 接口（缓存 30 分钟）· ' +
          '<a class="link-plain" href="' +
          RELEASES_URL +
          '" target="_blank" rel="noopener">在 GitHub 查看全部版本</a>';
      } else {
        note.innerHTML =
          '⚠️ 暂时读不到 GitHub 发布数据，下面是内置的版本记录。新版本请以 ' +
          '<a class="link-plain" href="' +
          RELEASES_URL +
          '" target="_blank" rel="noopener">GitHub Releases</a> 为准。' +
          '<button class="btn btn--ghost btn--sm" id="retry-live" type="button">重新拉取</button>';
        var retry = $('#retry-live');
        if (retry) {
          retry.addEventListener('click', function () {
            retry.disabled = true;
            retry.textContent = '拉取中…';
            try {
              sessionStorage.removeItem(CACHE_KEY);
            } catch (e) {
              /* 忽略 */
            }
            loadReleases().then(function (next) {
              if (next.live) {
                boot(next);
              } else {
                retry.disabled = false;
                retry.textContent = '重新拉取';
                toast('还是连不上 GitHub，稍后再试');
              }
            });
          });
        }
      }
    }
  }

  function caretSvg() {
    return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m6 9 6 6 6-6"/></svg>';
  }

  /** 折叠时显示的一句话摘要：取正文里第一段非标题文字 */
  function summarize(markdown) {
    var lines = String(markdown || '')
      .replace(/\r\n?/g, '\n')
      .split('\n');
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (!line || /^#{1,6}\s/.test(line) || /^(---|```)/.test(line)) continue;
      // 先摘掉引用 / 列表标记再做转义，否则转义后的 &gt; 会漏进摘要
      line = line.replace(/^>\s?/, '').replace(/^[-*+]\s+/, '');
      var text = inlineHtml(line).replace(/<[^>]+>/g, '');
      text = text.replace(/^[>\-\s]+/, '').trim();
      if (text) return text.length > 54 ? text.slice(0, 54) + '…' : text;
    }
    return '';
  }

  /* --------------------------- Markdown 渲染 --------------------------- */
  /* Release 正文只用到很有限的语法，这里手写一个够用的小解析器，
     比拉一个 Markdown 库（几十 KB）划算得多。顺序：先转义，再行内替换。 */

  function inlineHtml(text) {
    return escapeHtml(text)
      .replace(/`([^`]+)`/g, '<code>$1</code>')
      .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
      .replace(
        /\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g,
        '<a href="$2" target="_blank" rel="noopener">$1</a>'
      )
      .replace(/(^|[\s(])(https?:\/\/[^\s<)]+)/g, '$1<a href="$2" target="_blank" rel="noopener">$2</a>');
  }

  function markdownToHtml(markdown) {
    var lines = String(markdown || '')
      .replace(/\r\n?/g, '\n')
      .split('\n');
    var out = [];
    var para = [];
    var listType = null;
    var quote = [];
    var inCode = false;
    var codeBuffer = [];

    function flushPara() {
      if (para.length) {
        out.push('<p>' + inlineHtml(para.join(' ')) + '</p>');
        para = [];
      }
    }

    function flushList() {
      if (listType) {
        out.push('</' + listType + '>');
        listType = null;
      }
    }

    function flushQuote() {
      if (quote.length) {
        out.push('<blockquote>' + inlineHtml(quote.join(' ')) + '</blockquote>');
        quote = [];
      }
    }

    function flushAll() {
      flushPara();
      flushList();
      flushQuote();
    }

    for (var i = 0; i < lines.length; i++) {
      var raw = lines[i];
      var line = raw.replace(/\s+$/, '');

      if (/^\s*```/.test(line)) {
        if (inCode) {
          out.push('<pre><code>' + escapeHtml(codeBuffer.join('\n')) + '</code></pre>');
          codeBuffer = [];
          inCode = false;
        } else {
          flushAll();
          inCode = true;
        }
        continue;
      }
      if (inCode) {
        codeBuffer.push(raw);
        continue;
      }

      if (!line.trim()) {
        flushAll();
        continue;
      }

      if (/^(-{3,}|\*{3,}|_{3,})\s*$/.test(line.trim())) {
        flushAll();
        out.push('<hr>');
        continue;
      }

      var heading = line.match(/^(#{1,6})\s+(.*)$/);
      if (heading) {
        flushAll();
        // Release 正文里 # 是标题层级，页面里已经有一级 h2「更新日志」了，往下压两级
        var level = Math.min(heading[1].length + 2, 5);
        out.push(
          '<h' + level + '>' + inlineHtml(heading[2]) + '</h' + level + '>'
        );
        continue;
      }

      var quoteMatch = line.match(/^>\s?(.*)$/);
      if (quoteMatch) {
        flushPara();
        flushList();
        quote.push(quoteMatch[1]);
        continue;
      }

      var bullet = line.match(/^\s*[-*+]\s+(.*)$/);
      var ordered = line.match(/^\s*\d+[.)]\s+(.*)$/);
      if (bullet || ordered) {
        flushPara();
        flushQuote();
        var want = bullet ? 'ul' : 'ol';
        if (listType !== want) {
          flushList();
          out.push('<' + want + '>');
          listType = want;
        }
        out.push('<li>' + inlineHtml((bullet || ordered)[1]) + '</li>');
        continue;
      }

      // 列表项的续行：接到上一条里，别拆成新段落
      if (listType && /^\s+\S/.test(raw)) {
        var last = out.pop();
        out.push(last.replace(/<\/li>$/, ' ' + inlineHtml(line.trim()) + '</li>'));
        continue;
      }

      flushList();
      flushQuote();
      para.push(line.trim());
    }

    if (inCode && codeBuffer.length) {
      out.push('<pre><code>' + escapeHtml(codeBuffer.join('\n')) + '</code></pre>');
    }
    flushAll();
    return out.join('');
  }

  /* ----------------------------- 复制到剪贴板 ----------------------------- */

  function copyText(text, okMsg) {
    function done() {
      toast(okMsg || '已复制');
    }

    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(text).then(done, function () {
        fallbackCopy(text, done);
      });
      return;
    }
    fallbackCopy(text, done);
  }

  function fallbackCopy(text, done) {
    var area = document.createElement('textarea');
    area.value = text;
    area.setAttribute('readonly', '');
    area.style.position = 'fixed';
    area.style.opacity = '0';
    document.body.appendChild(area);
    area.select();
    try {
      document.execCommand('copy');
      done();
    } catch (e) {
      toast('复制失败，请手动选择');
    }
    document.body.removeChild(area);
  }

  /* ------------------------------- 启动 ------------------------------- */

  function boot(data) {
    var releases = data.releases || [];
    var latest =
      releases.filter(function (r) {
        return !r.draft && !r.prerelease;
      })[0] || releases[0];

    var normalized = normalizeRelease(latest);
    if (!data.live) {
      // 接口不可用：用兜底数据里的包名 / 大小 / 校验值 + 官方下载地址拼出可用链接
      normalized = normalizeRelease({
        tag_name: FALLBACK.tag,
        published_at: FALLBACK.publishedAt,
        assets: FALLBACK.assets.map(function (a) {
          return {
            name: a.name,
            size: null,
            sizeHuman: a.sizeHuman,
            digest: a.digest,
            browser_download_url:
              REPO_URL + '/releases/download/' + FALLBACK.tag + '/' + a.name,
          };
        }),
      });
    }

    renderDownload(normalized);
    renderChangelog(data);
  }

  function init() {
    initTheme();
    initNav();
    initReveal();

    loadReleases().then(function (data) {
      boot(data);
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
