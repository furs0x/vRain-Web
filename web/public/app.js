(function () {
  "use strict";

  const I18N = {
    zh: {
      tagline: "古籍刻本直排 · 只在這台電腦上執行",
      library: "書庫",
      newBook: "新書",
      idPh: "書籍 ID，例如 mybook",
      titlePh: "書名",
      authorPh: "作者",
      create: "建立",
      dup: "複製目前這本",
      del: "刪除",
      save: "儲存",
      gen: "開始排版",
      from: "起始序號",
      to: "結束序號",
      test: "測試頁數",
      testHint: "0 表示全書。序號是檔名排序後的順序，與命令列 -f -t 相同。",
      compress: "用 Ghostscript 壓縮",
      needGs: "未找到 Ghostscript，壓縮先關掉。產生 PDF 不需要它。",
      preview: "預覽",
      download: "下載 PDF",
      noPdf: "還沒有 PDF。",
      log: "日誌",
      text: "正文",
      textFile: "文本檔",
      addText: "新增一檔",
      uploadText: "上傳 .txt",
      raw: "原始 book.cfg",
      saveRaw: "儲存原始設定",
      uploadFont: "上傳字體",
      uploadBg: "上傳 JPEG 底圖",
      bgIdPh: "新底圖 ID",
      helpTitle: "正文標記",
      helpBody: "@ 代表空格。% 換葉。$ 換半葉。& 跳到本葉最後一列。\n【】雙行小字批注。《》書名側線。〔〕圓角框。〈〉圓框。\n（）字級縮放。｛｝圈注。＜＞點注。［］線注。\n行首 T 表示這一行頂格。設定值裡的空格會被 vrain.pl 去掉。",
      noModules: "這個 Perl 缺少 PDF::Builder 或 Font::FreeType。請改用可攜式套件裡的啟動程式，不要用系統裡另外裝的 Perl。",
      running: "排版中",
      done: "完成",
      failed: "失敗",
      saved: "已儲存",
      confirmDel: "確定刪除這本書？文本和 PDF 會一起刪掉。",
      newId: "新書 ID（英數，不能有空格）",
      canvas: "書葉背景",
      cols: "列",
      cover: "上傳封面 JPEG",
      langName: "EN",
      idle: "尚未排版",
      open: "開啟"
    },
    en: {
      tagline: "Vertical woodblock-style ebooks, on this computer only",
      library: "Library",
      newBook: "New book",
      idPh: "Book id, e.g. mybook",
      titlePh: "Title",
      authorPh: "Author",
      create: "Create",
      dup: "Duplicate",
      del: "Delete",
      save: "Save",
      gen: "Typeset",
      from: "From",
      to: "To",
      test: "Test pages",
      testHint: "0 typesets the whole book. Indexes follow filename order, same as -f and -t.",
      compress: "Compress with Ghostscript",
      needGs: "Ghostscript was not found, so compression stays off. PDFs still generate without it.",
      preview: "Preview",
      download: "Download PDF",
      noPdf: "No PDF yet.",
      log: "Log",
      text: "Text",
      textFile: "Text file",
      addText: "Add file",
      uploadText: "Upload .txt",
      raw: "Raw book.cfg",
      saveRaw: "Save raw config",
      uploadFont: "Upload font",
      uploadBg: "Upload JPEG background",
      bgIdPh: "New background id",
      helpTitle: "Markup",
      helpBody: "@ is a space. % is a new leaf. $ is a half leaf. & jumps to the last column.\n【】interlinear note. 《》title line. 〔〕rounded frame. 〈〉circle frame.\n（）size. ｛｝circle mark. ＜＞dot mark. ［］line mark.\nA leading T raises that line. vrain.pl removes spaces inside config values.",
      noModules: "This Perl is missing PDF::Builder or Font::FreeType. Start the app from the portable package.",
      running: "Typesetting",
      done: "Done",
      failed: "Failed",
      saved: "Saved",
      confirmDel: "Delete this book, including its text and PDFs?",
      newId: "New book id (letters, digits, _ or -)",
      canvas: "Page background",
      cols: "cols",
      cover: "Upload cover JPEG",
      langName: "繁",
      idle: "Idle",
      open: "Open"
    }
  };

  const GROUPS = [
    { id: "book", zh: "書籍", en: "Book", open: true },
    { id: "layout", zh: "版面", en: "Layout", open: true },
    { id: "font", zh: "字體", en: "Fonts", open: true },
    { id: "cover", zh: "封面與版心", en: "Cover and fold", open: false },
    { id: "punct", zh: "標點", en: "Punctuation", open: false },
    { id: "mark", zh: "標記", en: "Marks", open: false }
  ];

  const FIELDS = [
    ["book", "title", "書名", "Title", true],
    ["book", "author", "作者", "Author", true],
    ["layout", "row_num", "每列字數", "Characters per column", false],
    ["layout", "row_delta_y", "列末微調", "Column-end offset", false],
    ["layout", "multirows_horizontal_layout", "多欄橫排", "Multi-row layout", false],
    ["font", "font1", "主字體", "Primary font", false, "font"],
    ["font", "font2", "字體 2", "Font 2", false, "font"],
    ["font", "font3", "字體 3", "Font 3", false, "font"],
    ["font", "font4", "字體 4", "Font 4", false, "font"],
    ["font", "font5", "字體 5", "Font 5", false, "font"],
    ["font", "text_fonts_array", "正文字體順序", "Body font order", false],
    ["font", "text_font1_size", "正文 1 字號", "Body size 1", false],
    ["font", "text_font2_size", "正文 2 字號", "Body size 2", false],
    ["font", "text_font3_size", "正文 3 字號", "Body size 3", false],
    ["font", "text_font4_size", "正文 4 字號", "Body size 4", false],
    ["font", "text_font5_size", "正文 5 字號", "Body size 5", false],
    ["font", "text_font_color", "正文顏色", "Body color", false],
    ["font", "comment_fonts_array", "批注字體順序", "Note font order", false],
    ["font", "comment_font1_size", "批注 1 字號", "Note size 1", false],
    ["font", "comment_font2_size", "批注 2 字號", "Note size 2", false],
    ["font", "comment_font3_size", "批注 3 字號", "Note size 3", false],
    ["font", "comment_font4_size", "批注 4 字號", "Note size 4", false],
    ["font", "comment_font5_size", "批注 5 字號", "Note size 5", false],
    ["font", "comment_font_color", "批注顏色", "Note color", false],
    ["font", "font1_rotate", "字體 1 旋轉", "Font 1 rotate", false],
    ["font", "font2_rotate", "字體 2 旋轉", "Font 2 rotate", false],
    ["font", "font3_rotate", "字體 3 旋轉", "Font 3 rotate", false],
    ["font", "font4_rotate", "字體 4 旋轉", "Font 4 rotate", false],
    ["font", "font5_rotate", "字體 5 旋轉", "Font 5 rotate", false],
    ["font", "if_font_metric_adjust", "字體度量微調", "Metric adjust", false, "bool"],
    ["font", "if_fallback_bold", "回退字體加粗", "Fallback bold", false, "bool"],
    ["font", "fallback_bold_stroke_width", "加粗描邊", "Bold stroke", false],
    ["cover", "cover_title_font_size", "封面書名字號", "Cover title size", false],
    ["cover", "cover_title_y", "封面書名位置", "Cover title Y", false],
    ["cover", "cover_author_font_size", "封面作者字號", "Cover author size", false],
    ["cover", "cover_author_y", "封面作者位置", "Cover author Y", false],
    ["cover", "cover_font_color", "封面顏色", "Cover color", false],
    ["cover", "title_font_size", "版心標題字號", "Center title size", false],
    ["cover", "title_font_color", "版心標題顏色", "Center title color", false],
    ["cover", "title_y", "版心標題位置", "Center title Y", false],
    ["cover", "title_ydis", "標題字距", "Title spacing", false],
    ["cover", "title_postfix", "標題後綴", "Title suffix", false],
    ["cover", "title_directory", "產生目錄", "PDF outline", false, "bool"],
    ["cover", "pager_font_size", "頁碼字號", "Page number size", false],
    ["cover", "pager_font_color", "頁碼顏色", "Page number color", false],
    ["cover", "pager_y", "頁碼位置", "Page number Y", false],
    ["punct", "if_onlyperiod", "標點歸一為句號", "Only periods", false, "bool"],
    ["punct", "if_nocomma", "無標點模式", "Strip punctuation", false, "bool"],
    ["punct", "exp_replace_comma", "標點替換", "Punctuation replace", true],
    ["punct", "exp_replace_number", "數字替換", "Number replace", true],
    ["punct", "exp_delete_comma", "刪除符號", "Delete marks", true],
    ["punct", "exp_onlyperiod", "歸一句號的符號", "Marks folded to period", true],
    ["punct", "exp_nocomma", "無標點時刪除", "Marks removed in no-comma mode", true],
    ["punct", "text_comma_nop", "正文不佔位標點", "Body non-spacing marks", true],
    ["punct", "text_comma_nop_size", "不佔位大小", "Non-spacing size", false],
    ["punct", "text_comma_nop_x", "不佔位橫移", "Non-spacing X", false],
    ["punct", "text_comma_nop_y", "不佔位縱移", "Non-spacing Y", false],
    ["punct", "text_comma_90", "正文旋轉標點", "Body rotated marks", true],
    ["punct", "text_comma_90_size", "旋轉大小", "Rotated size", false],
    ["punct", "text_comma_90_x", "旋轉橫移", "Rotated X", false],
    ["punct", "text_comma_90_y", "旋轉縱移", "Rotated Y", false],
    ["punct", "comment_comma_nop", "批注不佔位標點", "Note non-spacing marks", true],
    ["punct", "comment_comma_nop_size", "批注不佔位大小", "Note non-spacing size", false],
    ["punct", "comment_comma_nop_x", "批注不佔位橫移", "Note non-spacing X", false],
    ["punct", "comment_comma_nop_y", "批注不佔位縱移", "Note non-spacing Y", false],
    ["punct", "comment_comma_90", "批注旋轉標點", "Note rotated marks", true],
    ["punct", "comment_comma_90_size", "批注旋轉大小", "Note rotated size", false],
    ["punct", "comment_comma_90_x", "批注旋轉橫移", "Note rotated X", false],
    ["punct", "comment_comma_90_y", "批注旋轉縱移", "Note rotated Y", false],
    ["mark", "if_tag_bookline", "《》書名側線", "Title side line", false, "bool"],
    ["mark", "book_line_width", "側線寬", "Line width", false],
    ["mark", "book_line_color", "側線顏色", "Line color", false],
    ["mark", "if_tag_rectframe", "〔〕圓角框", "Rounded frame", false, "bool"],
    ["mark", "rect_type", "框型", "Frame type", false],
    ["mark", "rect_bcolor", "框線色", "Frame stroke", false],
    ["mark", "rect_fcolor", "框填色", "Frame fill", false],
    ["mark", "text_rect_y", "正文框縱移", "Body frame Y", false],
    ["mark", "text_rect_h", "正文框高", "Body frame height", false],
    ["mark", "text_rect_r", "正文框圓角", "Body frame radius", false],
    ["mark", "comm_rect_y", "批注框縱移", "Note frame Y", false],
    ["mark", "comm_rect_h", "批注框高", "Note frame height", false],
    ["mark", "comm_rect_r", "批注框圓角", "Note frame radius", false],
    ["mark", "if_tag_circleframe", "〈〉圓框", "Circle frame", false, "bool"],
    ["mark", "circle_type", "圓框型", "Circle type", false],
    ["mark", "circle_bcolor", "圓框線色", "Circle stroke", false],
    ["mark", "circle_fcolor", "圓框填色", "Circle fill", false],
    ["mark", "text_circle_y", "正文圓縱移", "Body circle Y", false],
    ["mark", "text_circle_r", "正文圓半徑", "Body circle radius", false],
    ["mark", "text_circle_f", "正文圓比例", "Body circle factor", false],
    ["mark", "comm_circle_y", "批注圓縱移", "Note circle Y", false],
    ["mark", "comm_circle_r", "批注圓半徑", "Note circle radius", false],
    ["mark", "comm_circle_f", "批注圓比例", "Note circle factor", false],
    ["mark", "if_tag_textzoom", "（）縮放", "Size zoom", false, "bool"],
    ["mark", "text_zoom", "縮放倍率", "Zoom factor", false],
    ["mark", "if_tag_circlenote", "｛｝圈注", "Circle note", false, "bool"],
    ["mark", "text_note_ox", "圈注橫移", "Circle note X", false],
    ["mark", "text_note_oy", "圈注縱移", "Circle note Y", false],
    ["mark", "text_note_or", "圈注半徑", "Circle note radius", false],
    ["mark", "text_note_ow", "圈注線寬", "Circle note width", false],
    ["mark", "text_note_oc", "圈注顏色", "Circle note color", false],
    ["mark", "if_tag_pointnote", "＜＞點注", "Dot note", false, "bool"],
    ["mark", "text_note_px", "點注橫移", "Dot note X", false],
    ["mark", "text_note_py", "點注縱移", "Dot note Y", false],
    ["mark", "text_note_ps", "點注大小", "Dot note size", false],
    ["mark", "text_note_pc", "點注顏色", "Dot note color", false],
    ["mark", "if_tag_linenote", "［］線注", "Line note", false, "bool"],
    ["mark", "text_note_lx", "線注橫移", "Line note X", false],
    ["mark", "text_note_ly", "線注縱移", "Line note Y", false],
    ["mark", "text_note_lw", "線注線寬", "Line note width", false],
    ["mark", "text_note_lc", "線注顏色", "Line note color", false]
  ];

  const state = {
    lang: localStorage.getItem("vrain-lang") || "zh",
    catalog: null,
    health: null,
    bookId: null,
    book: null,
    textName: "01.txt",
    text: "",
    rawDirty: false,
    message: "",
    from: 1,
    to: 1,
    testPages: 1,
    compress: false,
    job: null,
    pollTimer: null
  };

  function t(key) {
    return (I18N[state.lang] && I18N[state.lang][key]) || I18N.zh[key] || key;
  }

  function esc(s) {
    return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  async function api(path, opt) {
    opt = opt || {};
    const headers = Object.assign({}, opt.headers || {});
    if (opt.json) {
      headers["Content-Type"] = "application/json";
      opt.body = JSON.stringify(opt.json);
    }
    const res = await fetch(path, { method: opt.method || "GET", headers: headers, body: opt.body });
    const type = res.headers.get("content-type") || "";
    const data = type.indexOf("json") >= 0 ? await res.json() : await res.text();
    if (!res.ok) {
      const msg = data && data.error ? data.error : res.status + " " + res.statusText;
      throw new Error(msg);
    }
    return data;
  }

  function setMessage(msg) {
    state.message = msg || "";
    const el = document.getElementById("banner");
    if (el) {
      el.hidden = !state.message;
      el.textContent = state.message;
    }
  }

  function fieldValue(key) {
    if (!state.book || !state.book.config) return "";
    const v = state.book.config[key];
    return v == null ? "" : String(v);
  }

  function fontOptions(current) {
    const names = (state.catalog.fonts || []).map(function (f) { return f.name; });
    if (current && names.indexOf(current) < 0) names.unshift(current);
    let html = '<option value=""></option>';
    names.forEach(function (name) {
      html += '<option value="' + esc(name) + '"' + (name === current ? " selected" : "") + ">" + esc(name) + "</option>";
    });
    return html;
  }

  function boolOptions(current) {
    const v = current === "1" ? "1" : "0";
    return '<option value="0"' + (v === "0" ? " selected" : "") + ">0</option>" +
      '<option value="1"' + (v === "1" ? " selected" : "") + ">1</option>";
  }

  function renderFields(group) {
    return FIELDS.filter(function (f) { return f[0] === group; }).map(function (f) {
      const key = f[1];
      const label = state.lang === "en" ? f[3] : f[2];
      const wide = f[4] ? " wide" : "";
      const kind = f[5] || "text";
      const value = fieldValue(key);
      let control;
      if (kind === "font") control = '<select data-key="' + key + '">' + fontOptions(value) + "</select>";
      else if (kind === "bool") control = '<select data-key="' + key + '">' + boolOptions(value) + "</select>";
      else control = '<input data-key="' + key + '" value="' + esc(value) + '">';
      return '<label class="field' + wide + '"><span>' + esc(label) + "</span>" + control + "</label>";
    }).join("");
  }

  function canvasBar() {
    const current = fieldValue("canvas_id");
    const buttons = (state.catalog.canvases || []).map(function (c) {
      return '<button type="button" data-act="canvas" data-id="' + esc(c.id) + '" class="' + (c.id === current ? "selected" : "") + '">' +
        '<img alt="' + esc(c.id) + '" src="/media/canvas/' + encodeURIComponent(c.id) + '.jpg" loading="lazy">' +
        "</button>";
    }).join("");
    const info = (state.catalog.canvases || []).filter(function (c) { return c.id === current; })[0];
    const line = info ? (info.width + "×" + info.height + "  " + t("cols") + " " + info.columns + (info.logo ? "  " + info.logo : "")) : "";
    return '<div class="canvases">' + buttons + '</div><div class="meta" id="canvasInfo">' + esc(line) + "</div>" +
      '<div class="row"><input id="bgId" placeholder="' + esc(t("bgIdPh")) + '"><button type="button" class="ghost" data-act="pick-bg">' +
      esc(t("uploadBg")) + "</button></div>";
  }

  function textOptions() {
    const texts = (state.book && state.book.texts) || [];
    if (!texts.length) return '<option value="01.txt">01.txt</option>';
    return texts.map(function (item) {
      return '<option value="' + esc(item.name) + '"' + (item.name === state.textName ? " selected" : "") + ">" +
        esc(item.name) + "</option>";
    }).join("");
  }

  function pdfBlock() {
    const pdfs = (state.book && state.book.pdfs) || [];
    if (!pdfs.length) return '<p class="meta">' + esc(t("noPdf")) + "</p>";
    const pdf = pdfs[0];
    const url = "/api/books/" + encodeURIComponent(state.bookId) + "/pdf?name=" + encodeURIComponent(pdf.name);
    return '<p><a href="' + url + '&amp;download=1">' + esc(t("download")) + "</a> · " + esc(pdf.name) + "</p>" +
      '<iframe title="pdf" src="' + url + '"></iframe>';
  }

  function render() {
    const books = (state.catalog && state.catalog.books) || [];
    const bookButtons = books.map(function (b) {
      return '<button type="button" data-act="open" data-id="' + esc(b.id) + '" class="' + (b.id === state.bookId ? "selected" : "") + '">' +
        esc(b.title || b.id) + "<small>" + esc(b.id) + (b.author ? " · " + esc(b.author) : "") + "</small></button>";
    }).join("");
    const groups = GROUPS.map(function (g) {
      const label = state.lang === "en" ? g.en : g.zh;
      const extra = g.id === "layout" ? '<div class="field wide"><span>' + esc(t("canvas")) + "</span>" + canvasBar() + "</div>" : "";
      return "<details " + (g.open ? "open" : "") + "><summary>" + esc(label) + "</summary><div class=\"fields\">" +
        extra + renderFields(g.id) + "</div></details>";
    }).join("");
    const moduleWarn = state.health && state.health.modules === false
      ? '<div class="modules">' + esc(t("noModules")) + "</div>" : "";
    const gsHint = state.health && state.health.ghostscript === false
      ? '<p class="meta">' + esc(t("needGs")) + "</p>" : "";
    const jobClass = state.job ? state.job.status : "idle";
    const jobText = !state.job ? t("idle") : (state.job.status === "running" ? t("running") : state.job.status === "done" ? t("done") : t("failed"));

    document.getElementById("app").innerHTML =
      '<header class="top">' +
        '<div class="seal">兀雨</div>' +
        '<div class="brand"><h1>vRain</h1><p>' + esc(t("tagline")) + "</p></div>" +
        '<div class="spacer"></div>' +
        '<button type="button" class="ghost lang" data-act="lang">' + esc(t("langName")) + "</button>" +
      "</header>" +
      '<div id="banner" class="banner"' + (state.message ? "" : " hidden") + ">" + esc(state.message) + "</div>" +
      '<aside class="side"><h2>' + esc(t("library")) + "</h2>" + moduleWarn +
        '<div class="books">' + bookButtons + "</div>" +
        '<form class="create" data-act-form="create">' +
          "<h2>" + esc(t("newBook")) + "</h2>" +
          '<input name="id" required pattern="[A-Za-z0-9][A-Za-z0-9_\\-]{0,40}" placeholder="' + esc(t("idPh")) + '">' +
          '<input name="title" placeholder="' + esc(t("titlePh")) + '">' +
          '<input name="author" placeholder="' + esc(t("authorPh")) + '">' +
          '<button type="submit" class="primary">' + esc(t("create")) + "</button>" +
        "</form></aside>" +
      '<main class="main">' +
        '<div class="row">' +
          '<button type="button" class="primary" id="saveBtn" data-act="save">' + esc(t("save")) + "</button>" +
          '<button type="button" class="primary" id="genBtn" data-act="generate">' + esc(t("gen")) + "</button>" +
          '<button type="button" class="ghost" data-act="duplicate">' + esc(t("dup")) + "</button>" +
          (state.book && state.book.protected ? "" : '<button type="button" class="danger" data-act="delete">' + esc(t("del")) + "</button>") +
        "</div>" +
        groups +
        "<h2>" + esc(t("text")) + "</h2>" +
        '<div class="row"><label class="grow">' + esc(t("textFile")) +
          ' <select id="textFile">' + textOptions() + "</select></label>" +
          '<button type="button" class="ghost" data-act="add-text">' + esc(t("addText")) + "</button>" +
          '<button type="button" class="ghost" data-act="upload-text">' + esc(t("uploadText")) + "</button>" +
          '<button type="button" class="ghost" data-act="upload-font">' + esc(t("uploadFont")) + "</button>" +
          '<button type="button" class="ghost" data-act="upload-cover">' + esc(t("cover")) + "</button>" +
        "</div>" +
        '<textarea id="text">' + esc(state.text) + "</textarea>" +
        "<details><summary>" + esc(t("helpTitle")) + "</summary><div class=\"help\">" + esc(t("helpBody")) + "</div></details>" +
        "<details><summary>" + esc(t("raw")) + "</summary>" +
          '<textarea id="raw">' + esc(state.book ? state.book.raw : "") + "</textarea>" +
          '<div class="row"><button type="button" data-act="save-raw">' + esc(t("saveRaw")) + "</button></div>" +
        "</details>" +
        '<div class="row">' +
          '<label>' + esc(t("from")) + ' <input id="from" type="number" min="1" value="' + esc(state.from) + '"></label>' +
          '<label>' + esc(t("to")) + ' <input id="to" type="number" min="1" value="' + esc(state.to) + '"></label>' +
          '<label>' + esc(t("test")) + ' <input id="testPages" type="number" min="0" value="' + esc(state.testPages) + '"></label>' +
          '<label><input id="compress" type="checkbox"' + (state.compress ? " checked" : "") + (state.health && state.health.ghostscript ? "" : " disabled") + "> " + esc(t("compress")) + "</label>" +
        "</div>" +
        '<p class="meta">' + esc(t("testHint")) + "</p>" + gsHint +
      "</main>" +
      '<section class="preview"><h2>' + esc(t("preview")) + "</h2>" + pdfBlock() +
        "<h2>" + esc(t("log")) + '</h2><p class="jobstate ' + esc(jobClass) + '" id="jobstate">' + esc(jobText) + "</p>" +
        '<pre id="log">' + esc(state.job && state.job.log ? state.job.log : "") + "</pre></section>";

    const gen = document.getElementById("genBtn");
    if (gen && state.job && state.job.status === "running") gen.disabled = true;
  }

  function syncFromDom() {
    if (!state.book) return;
    document.querySelectorAll("[data-key]").forEach(function (el) {
      state.book.config[el.dataset.key] = el.value;
    });
    const text = document.getElementById("text");
    if (text) state.text = text.value;
    const raw = document.getElementById("raw");
    if (raw) state.book.raw = raw.value;
    const from = document.getElementById("from");
    const to = document.getElementById("to");
    const testPages = document.getElementById("testPages");
    const compress = document.getElementById("compress");
    if (from) state.from = Number(from.value || 1);
    if (to) state.to = Number(to.value || 1);
    if (testPages) state.testPages = Number(testPages.value || 0);
    if (compress) state.compress = !!compress.checked;
  }

  async function openBook(id, keepMessage) {
    syncFromDom();
    const detail = await api("/api/books/" + encodeURIComponent(id));
    state.bookId = id;
    state.book = detail;
    state.rawDirty = false;
    localStorage.setItem("vrain-book", id);
    const texts = detail.texts || [];
    state.textName = texts.some(function (item) { return item.name === "01.txt"; }) ? "01.txt" : (texts[0] ? texts[0].name : "01.txt");
    if (texts.length) {
      const body = await api("/api/books/" + encodeURIComponent(id) + "/text/" + encodeURIComponent(state.textName));
      state.text = body.text || "";
    } else {
      state.text = "";
    }
    state.to = Math.max(1, texts.length || 1);
    if (!keepMessage) state.message = "";
    render();
  }

  async function loadText(name) {
    syncFromDom();
    await api("/api/books/" + encodeURIComponent(state.bookId) + "/text/" + encodeURIComponent(state.textName), {
      method: "PUT",
      json: { text: state.text }
    });
    state.textName = name;
    const body = await api("/api/books/" + encodeURIComponent(state.bookId) + "/text/" + encodeURIComponent(name));
    state.text = body.text || "";
    render();
  }

  async function saveAll() {
    syncFromDom();
    if (state.rawDirty) {
      await api("/api/books/" + encodeURIComponent(state.bookId) + "/config", {
        method: "PUT",
        json: { raw: state.book.raw }
      });
      state.rawDirty = false;
    } else {
      await api("/api/books/" + encodeURIComponent(state.bookId) + "/config", {
        method: "PUT",
        json: { values: state.book.config }
      });
    }
    await api("/api/books/" + encodeURIComponent(state.bookId) + "/text/" + encodeURIComponent(state.textName), {
      method: "PUT",
      json: { text: state.text }
    });
  }

  function watchJob(id) {
    if (state.pollTimer) clearInterval(state.pollTimer);
    state.pollTimer = setInterval(async function () {
      try {
        const job = await api("/api/jobs/" + encodeURIComponent(id));
        state.job = job;
        const log = document.getElementById("log");
        const label = document.getElementById("jobstate");
        if (log) {
          const stick = log.scrollTop + log.clientHeight >= log.scrollHeight - 30;
          log.textContent = job.log || "";
          if (stick) log.scrollTop = log.scrollHeight;
        }
        if (label) {
          label.className = "jobstate " + job.status;
          label.textContent = job.status === "running" ? t("running") : job.status === "done" ? t("done") : t("failed");
        }
        const gen = document.getElementById("genBtn");
        if (gen) gen.disabled = job.status === "running";
        if (job.status !== "running") {
          clearInterval(state.pollTimer);
          state.pollTimer = null;
          const detail = await api("/api/books/" + encodeURIComponent(state.bookId));
          state.book.pdfs = detail.pdfs;
          state.book.raw = detail.raw;
          state.book.config = detail.config;
          render();
          if (job.status === "error") setMessage(t("failed"));
        }
      } catch (err) {
        setMessage(err.message);
      }
    }, 700);
  }

  function pickFile(accept) {
    return new Promise(function (resolve) {
      const input = document.createElement("input");
      input.type = "file";
      input.accept = accept;
      input.onchange = function () { resolve(input.files && input.files[0]); };
      input.click();
    });
  }

  async function refreshCatalog() {
    state.catalog = await api("/api/catalog");
  }

  document.body.addEventListener("input", function (event) {
    if (event.target && event.target.id === "raw") state.rawDirty = true;
  });

  document.body.addEventListener("change", function (event) {
    if (event.target && event.target.id === "textFile") {
      loadText(event.target.value).catch(function (err) { setMessage(err.message); });
    }
  });

  document.body.addEventListener("submit", function (event) {
    const form = event.target.closest("[data-act-form]");
    if (!form) return;
    event.preventDefault();
    if (form.dataset.actForm === "create") {
      const body = {
        id: form.elements.id.value.trim(),
        title: form.elements.title.value.trim() || form.elements.id.value.trim(),
        author: form.elements.author.value.trim(),
        canvas_id: "vintage",
        template: "sample",
        text: ""
      };
      api("/api/books", { method: "POST", json: body }).then(function () {
        return refreshCatalog();
      }).then(function () {
        return openBook(body.id);
      }).catch(function (err) { setMessage(err.message); });
    }
  });

  document.body.addEventListener("click", function (event) {
    const btn = event.target.closest("[data-act]");
    if (!btn) return;
    const act = btn.dataset.act;
    if (act === "lang") {
      syncFromDom();
      state.lang = state.lang === "zh" ? "en" : "zh";
      localStorage.setItem("vrain-lang", state.lang);
      document.documentElement.lang = state.lang === "zh" ? "zh-Hant" : "en";
      render();
      return;
    }
    if (act === "open") {
      openBook(btn.dataset.id).catch(function (err) { setMessage(err.message); });
      return;
    }
    if (act === "canvas") {
      state.book.config.canvas_id = btn.dataset.id;
      document.querySelectorAll(".canvases button").forEach(function (el) {
        el.classList.toggle("selected", el.dataset.id === btn.dataset.id);
      });
      const info = (state.catalog.canvases || []).filter(function (c) { return c.id === btn.dataset.id; })[0];
      const node = document.getElementById("canvasInfo");
      if (node && info) node.textContent = info.width + "×" + info.height + "  " + t("cols") + " " + info.columns + (info.logo ? "  " + info.logo : "");
      return;
    }
    if (act === "save") {
      saveAll().then(function () {
        return openBook(state.bookId, true);
      }).then(function () { setMessage(t("saved")); }).catch(function (err) { setMessage(err.message); });
      return;
    }
    if (act === "save-raw") {
      state.rawDirty = true;
      saveAll().then(function () {
        return openBook(state.bookId, true);
      }).then(function () { setMessage(t("saved")); }).catch(function (err) { setMessage(err.message); });
      return;
    }
    if (act === "generate") {
      saveAll().then(function () {
        return api("/api/jobs", {
          method: "POST",
          json: {
            book: state.bookId,
            from: state.from,
            to: state.to,
            testPages: state.testPages,
            compress: state.compress
          }
        });
      }).then(function (job) {
        state.job = { id: job.id, status: "running", log: "" };
        render();
        watchJob(job.id);
      }).catch(function (err) { setMessage(err.message); });
      return;
    }
    if (act === "delete") {
      if (!confirm(t("confirmDel"))) return;
      api("/api/books/" + encodeURIComponent(state.bookId), { method: "DELETE" }).then(function () {
        return refreshCatalog();
      }).then(function () {
        const next = state.catalog.books[0];
        return next ? openBook(next.id) : null;
      }).catch(function (err) { setMessage(err.message); });
      return;
    }
    if (act === "duplicate") {
      const id = prompt(t("newId"));
      if (!id) return;
      syncFromDom();
      api("/api/books", {
        method: "POST",
        json: {
          id: id.trim(),
          template: state.bookId,
          title: state.book.config.title,
          author: state.book.config.author,
          canvas_id: state.book.config.canvas_id,
          text: state.text
        }
      }).then(function () {
        return refreshCatalog();
      }).then(function () { return openBook(id.trim()); }).catch(function (err) { setMessage(err.message); });
      return;
    }
    if (act === "add-text") {
      syncFromDom();
      const names = (state.book.texts || []).map(function (item) { return item.name; });
      let n = names.length + 1;
      let name = String(n).padStart(2, "0") + ".txt";
      while (names.indexOf(name) >= 0) {
        n += 1;
        name = String(n).padStart(2, "0") + ".txt";
      }
      api("/api/books/" + encodeURIComponent(state.bookId) + "/text/" + encodeURIComponent(state.textName), {
        method: "PUT",
        json: { text: state.text }
      }).then(function () {
        return api("/api/books/" + encodeURIComponent(state.bookId) + "/text/" + encodeURIComponent(name), {
          method: "PUT",
          json: { text: "" }
        });
      }).then(function () { return openBook(state.bookId, true); }).then(function () {
        return loadText(name);
      }).catch(function (err) { setMessage(err.message); });
      return;
    }
    if (act === "upload-text") {
      pickFile(".txt,text/plain").then(function (file) {
        if (!file) return;
        return file.text().then(function (text) {
          state.text = text;
          const area = document.getElementById("text");
          if (area) area.value = text;
        });
      }).catch(function (err) { setMessage(err.message); });
      return;
    }
    if (act === "upload-font") {
      pickFile(".ttf,.otf,.ttc").then(function (file) {
        if (!file) return null;
        return file.arrayBuffer().then(function (buf) {
          return api("/api/fonts", {
            method: "POST",
            headers: { "X-Filename": file.name },
            body: buf
          });
        });
      }).then(function (uploaded) {
        if (!uploaded) return;
        return refreshCatalog();
      }).then(function (catalog) {
        if (!catalog) return;
        syncFromDom();
        render();
        setMessage(t("saved"));
      }).catch(function (err) { setMessage(err.message); });
      return;
    }
    if (act === "upload-cover") {
      pickFile("image/jpeg,.jpg,.jpeg").then(function (file) {
        if (!file) return;
        return file.arrayBuffer().then(function (buf) {
          return api("/api/books/" + encodeURIComponent(state.bookId) + "/cover", { method: "POST", body: buf });
        });
      }).then(function () { setMessage(t("saved")); }).catch(function (err) { setMessage(err.message); });
      return;
    }
    if (act === "pick-bg") {
      const idInput = document.getElementById("bgId");
      const id = idInput ? idInput.value.trim() : "";
      if (!id) { setMessage(t("bgIdPh")); return; }
      pickFile("image/jpeg,.jpg,.jpeg").then(function (file) {
        if (!file) return;
        return file.arrayBuffer().then(function (buf) {
          return api("/api/canvases", {
            method: "POST",
            headers: {
              "X-Canvas-Id": id,
              "X-Source-Canvas": state.book.config.canvas_id || "vintage"
            },
            body: buf
          });
        });
      }).then(function () {
        return refreshCatalog();
      }).then(function () {
        state.book.config.canvas_id = id;
        render();
      }).catch(function (err) { setMessage(err.message); });
    }
  });

  document.documentElement.lang = state.lang === "zh" ? "zh-Hant" : "en";
  Promise.all([api("/api/health"), api("/api/catalog")]).then(function (pair) {
    state.health = pair[0];
    state.catalog = pair[1];
    const saved = localStorage.getItem("vrain-book");
    const exists = (state.catalog.books || []).some(function (b) { return b.id === saved; });
    const id = exists ? saved : ((state.catalog.books[0] && state.catalog.books[0].id) || "sample");
    return openBook(id);
  }).catch(function (err) {
    document.getElementById("app").textContent = err.message;
  });
})();
