(() => {
  const root = document.documentElement;
  root.classList.add('enhanced');

  document.querySelectorAll('[data-copy]').forEach((button) => {
    button.addEventListener('click', async () => {
      const code = button.closest('.code-block')?.querySelector('code')?.textContent;
      if (!code) return;
      try {
        await navigator.clipboard.writeText(code.replace(/\n$/, ''));
        button.textContent = 'Copied';
        window.setTimeout(() => { button.textContent = 'Copy'; }, 1400);
      } catch {
        button.textContent = 'Select';
      }
    });
  });

  const dialog = document.querySelector('[data-search-dialog]');
  const input = dialog?.querySelector('input');
  const results = dialog?.querySelector('.search-results');
  let index;

  const loadIndex = async () => {
    if (!index) {
      const response = await fetch('/docs/search-index.json');
      index = await response.json();
    }
    return index;
  };

  const score = (page, terms) => {
    const title = page.title.toLowerCase();
    const text = page.text.toLowerCase();
    return terms.reduce((total, term) => {
      if (!text.includes(term) && !title.includes(term)) return -1000;
      return total + (title.includes(term) ? 12 : 0) + (text.includes(term) ? 2 : 0);
    }, 0);
  };

  const render = async () => {
    const terms = input.value.toLowerCase().trim().split(/\s+/).filter(Boolean);
    results.replaceChildren();
    if (!terms.length) {
      const hint = document.createElement('p');
      hint.className = 'search-hint';
      hint.textContent = 'Search commands, operators, YAML features, or tasks.';
      results.append(hint);
      return;
    }
    const pages = (await loadIndex())
      .map((page) => ({ page, score: score(page, terms) }))
      .filter((result) => result.score >= 0)
      .sort((a, b) => b.score - a.score)
      .slice(0, 8);
    if (!pages.length) {
      const empty = document.createElement('p');
      empty.className = 'search-hint';
      empty.textContent = 'No matching page. Try fewer words.';
      results.append(empty);
      return;
    }
    pages.forEach(({ page }) => {
      const link = document.createElement('a');
      link.href = page.url;
      const title = document.createElement('strong');
      title.textContent = page.title;
      const path = document.createElement('span');
      path.textContent = page.url;
      link.append(title, path);
      results.append(link);
    });
  };

  const openSearch = async () => {
    if (!dialog || !input) return;
    if (!dialog.open) dialog.showModal();
    input.focus();
    try {
      await render();
    } catch {
      results.replaceChildren();
      const error = document.createElement('p');
      error.className = 'search-hint';
      error.textContent = 'Search is unavailable. The navigation still has every page.';
      results.append(error);
    }
  };

  document.querySelectorAll('[data-search-open]').forEach((button) => {
    button.addEventListener('click', openSearch);
  });
  input?.addEventListener('input', render);
  dialog?.addEventListener('keydown', (event) => {
    const links = [...results.querySelectorAll('a')];
    if (!links.length) return;
    if (event.key === 'Enter' && document.activeElement === input) {
      event.preventDefault();
      links[0].click();
      return;
    }
    if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp') return;
    event.preventDefault();
    const current = links.indexOf(document.activeElement);
    const step = event.key === 'ArrowDown' ? 1 : -1;
    const next = current < 0 ? (step > 0 ? 0 : links.length - 1) : (current + step + links.length) % links.length;
    links[next].focus();
  });
  dialog?.addEventListener('click', (event) => {
    if (event.target === dialog) dialog.close();
  });
  document.addEventListener('keydown', (event) => {
    const typing = /INPUT|TEXTAREA|SELECT/.test(document.activeElement?.tagName || '');
    if ((event.key === '/' && !typing) || ((event.metaKey || event.ctrlKey) && event.key === 'k')) {
      event.preventDefault();
      openSearch();
    }
  });

  document.querySelectorAll('.mobile-docs a').forEach((link) => {
    link.addEventListener('click', () => link.closest('details')?.removeAttribute('open'));
  });
})();
