// Adds a Copy button to every command block (.cmd pre). The page works without it: commands stay selectable.
(function () {
  function fallback(text) {
    var ta = document.createElement('textarea');
    ta.value = text; ta.setAttribute('readonly', ''); ta.style.position = 'fixed'; ta.style.opacity = '0';
    document.body.appendChild(ta); ta.select();
    try { document.execCommand('copy'); } catch (e) { /* the user can still select the text */ }
    document.body.removeChild(ta);
  }
  function addButtons() {
    var blocks = document.querySelectorAll('.cmd pre');
    for (var i = 0; i < blocks.length; i++) {
      (function (pre) {
        var code = pre.querySelector('code') || pre;
        var btn = document.createElement('button');
        btn.type = 'button'; btn.className = 'copy'; btn.textContent = 'Copy';
        btn.setAttribute('aria-label', 'Copy command');
        btn.addEventListener('click', function () {
          var text = code.textContent.replace(/\s+$/, '');
          var done = function () {
            btn.textContent = 'Copied';
            setTimeout(function () { btn.textContent = 'Copy'; }, 1500);
          };
          if (navigator.clipboard && window.isSecureContext) {
            navigator.clipboard.writeText(text).then(done, function () { fallback(text); done(); });
          } else { fallback(text); done(); }
        });
        pre.appendChild(btn);
      })(blocks[i]);
    }
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', addButtons);
  else addButtons();
})();
