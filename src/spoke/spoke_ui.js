// spoke_ui.js
// jsui object — renders track identity as a visual panel in the M4L device.
// Receives a JSON string via the parse() handler.
// Displays: color swatch | track name | category label

mgraphics.init();
mgraphics.relative_coords = 0;
mgraphics.autofill = 0;

autowatch = 1;

var meta = { name: 'loading...', color: 0x444444, category: '—' };

// Called by Max when a message arrives prefixed with "parse"
// e.g. the patch sends: prepend parse → jsui
function parse(s) {
  try {
    meta = JSON.parse(s);
    refresh();
  } catch (e) {
    error('spoke_ui: parse error — ' + e + '\n');
  }
}

function paint() {
  var w = this.box.rect[2] - this.box.rect[0];
  var h = this.box.rect[3] - this.box.rect[1];

  // --- background ---
  mgraphics.set_source_rgba(0.1, 0.1, 0.1, 1.0);
  mgraphics.rectangle(0, 0, w, h);
  mgraphics.fill();

  // --- color swatch (left strip, 6px wide) ---
  var r = ((meta.color >> 16) & 0xFF) / 255.0;
  var g = ((meta.color >>  8) & 0xFF) / 255.0;
  var b = ((meta.color      ) & 0xFF) / 255.0;
  mgraphics.set_source_rgba(r, g, b, 1.0);
  mgraphics.rectangle(0, 0, 6, h);
  mgraphics.fill();

  // --- track name ---
  mgraphics.select_font_face('Arial');
  mgraphics.set_font_size(11);
  mgraphics.set_source_rgba(1.0, 1.0, 1.0, 1.0);
  mgraphics.move_to(14, 17);
  mgraphics.show_text(meta.name);

  // --- category badge ---
  var badgeText = meta.category;
  mgraphics.set_font_size(9);

  // badge background pill
  mgraphics.set_source_rgba(0.25, 0.25, 0.25, 1.0);
  mgraphics.rectangle(13, 22, 60, 13);
  mgraphics.fill();

  // badge text
  mgraphics.set_source_rgba(0.7, 0.7, 0.7, 1.0);
  mgraphics.move_to(16, 32);
  mgraphics.show_text(badgeText);
}
