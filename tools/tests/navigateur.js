// Vérification de la version web dans Chromium : menu, cachette, atelier (orbite, molette), sans erreur console.
// Préparer un dossier avec la page de l'artefact (index.html = tools/artefact/duel-des-cimes.html) et ses fichiers
// (index.js, worklets, moteur-gz.wasm, donnees-pck.wasm = index.pck exporté), le servir sur le port 8123
// (python3 -m http.server 8123), puis :  node tools/tests/navigateur.js /dossier/captures souris|doigt
// « doigt » : téléphone debout 390×844 en mode ?tactile (la souris fait le doigt). Rendu logiciel : ≈ 6 min.
const { chromium } = require('playwright');
const out = process.argv[2], mode = process.argv[3] || 'souris';
(async () => {
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const portrait = mode === 'doigt';
  const realTouch = false;   // les touchers CDP n'atteignent pas Godot ici : la souris fait le doigt (?tactile)
  const ctx = await browser.newContext(portrait ? { viewport: { width: 390, height: 844 } } : { viewport: { width: 1280, height: 720 } });
  const page = await ctx.newPage();
  const logs = [];
  page.on('console', (m) => logs.push(m.type() + ': ' + m.text()));
  page.setDefaultTimeout(180000);
  page.on('pageerror', (e) => logs.push('pageerror: ' + e.message));
  await page.goto('http://localhost:8123/' + (portrait ? '?tactile' : ''));
  const W = portrait ? 390 : 1280, H = portrait ? 844 : 720;
  await page.waitForFunction(() => document.getElementById('loader').hidden, null, { timeout: 900000, polling: 2000 });
  console.log('moteur démarré', Date.now());
  // L'enveloppe de claude.ai masque les éléments [hidden] ; en local, on fait pareil.
  await page.addStyleTag({ content: '[hidden]{display:none!important}' });
  // Attendre la fin du chargement : l'image ne change plus pendant 10 s.
  let prev = null, stable = 0;
  for (let i = 0; i < 90 && stable < 2; i++) {
    await page.waitForTimeout(5000);
    let b; try { b = await page.screenshot({ timeout: 120000 }); } catch (e) { console.log('capture lente', i); continue; }
    stable = prev && b.equals(prev) ? stable + 1 : 0;
    prev = b;
  }
  await page.screenshot({ path: out + '/1_menu.png', timeout: 180000 }); console.log('menu', Date.now());
  const shot = async (n) => { await page.waitForTimeout(4000); await page.screenshot({ path: out + '/' + n + '.png', timeout: 180000 }); console.log(n); };
  const tap = async (x, y) => {
    if (portrait && realTouch) {
      const cdp = await ctx.newCDPSession(page);
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y, id: 0 }] });
      await page.waitForTimeout(150);
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    } else { await page.mouse.click(x, y); }
  };
  const orange = (f) => require('child_process').execSync('python3 ' + __dirname + '/bouton_orange.py ' + f).toString().trim().split(' ').map(Number);
  // JOUER
  const [jx, jy] = portrait ? orange(out + '/1_menu.png') : [912, 592];
  console.log('JOUER', jx, jy);
  await tap(jx, jy);
  await shot('2_cachette');
  // Prêt → atelier
  if (portrait) { const [px, py] = orange(out + '/2_cachette.png'); console.log('PRET', px, py); await tap(px, py); } else { await page.keyboard.press('Escape'); await page.keyboard.press('Enter'); }
  await shot('3_atelier');
  // Orbite
  const cx = W * 0.55, cy = H * 0.5;
  if (portrait && realTouch) {
    const cdp = await ctx.newCDPSession(page);
    const t = async (type, pts) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: pts });
    await t('touchStart', [{ x: cx, y: cy, id: 0 }]);
    for (let k = 1; k <= 10; k++) { await t('touchMove', [{ x: cx + k * 12, y: cy - k * 3, id: 0 }]); await page.waitForTimeout(30); }
    await t('touchEnd', []);
  } else {
    await page.mouse.move(cx, cy);
    await page.mouse.down();
    for (let k = 1; k <= 10; k++) { await page.mouse.move(cx - k * 14, cy + k * 5); await page.waitForTimeout(30); }
    await page.mouse.up();
  }
  await shot('4_atelier_orbite');
  if (portrait && realTouch) {
    const cdp = await ctx.newCDPSession(page);
    const t = async (type, pts) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: pts });
    await t('touchStart', [{ x: cx - 40, y: cy, id: 0 }, { x: cx + 40, y: cy, id: 1 }]);
    for (let k = 1; k <= 10; k++) { await t('touchMove', [{ x: cx - 40 - k * 8, y: cy, id: 0 }, { x: cx + 40 + k * 8, y: cy, id: 1 }]); await page.waitForTimeout(30); }
    await t('touchEnd', []);
  } else {
    await page.mouse.move(cx, cy);
    for (let k = 0; k < 4; k++) { await page.mouse.wheel(0, -120); await page.waitForTimeout(50); }
  }
  await shot('5_atelier_zoom');
  if (!portrait) {
    // Fin de l'atelier (TERMINÉ), révélation, puis tir : zoom (touche Z) et tir (Espace).
    const [tx, ty] = orange(out + '/5_atelier_zoom.png');
    console.log('TERMINE', tx, ty);
    await tap(tx, ty);
    // Rendu logiciel : le jeu tourne lentement ; on attend la fin du brouillard (le zoom n'agit qu'au tir).
    await page.waitForTimeout(150000);
    await shot('6_tir_x1');
    await page.keyboard.press('z');
    await page.waitForTimeout(10000);
    await shot('7_tir_x4');
    await page.keyboard.press('z');
    await page.waitForTimeout(10000);
    await shot('8_tir_x10');
    await page.keyboard.press('Space');
    await page.waitForTimeout(1000);
    await shot('9_tir_recul');
  }
  require('fs').writeFileSync(out + '/console.txt', logs.join('\n'));
  await browser.close();
})();
