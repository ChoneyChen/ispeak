const examples = {
  1: {
    experience: '平时上班前会跑步，跑完觉得脑子更清醒。',
    grammar: '一般现在时 + because · 习惯与原因',
    sentence: '<mark>I usually go</mark> for a run before work <mark>because it helps me</mark> clear my head.',
    translation: '我通常在上班前跑步，因为这能帮我理清思绪。',
    purpose: '回答日常喜好，再自然地补一句为什么。'
  },
  2: {
    experience: '组织过一次分享，没提前检查设备，临场有点慌。',
    grammar: '第三条件句 · 反思过去',
    sentence: '<mark>If I’d checked</mark> the equipment earlier, <mark>I would have felt</mark> more relaxed.',
    translation: '如果我早点检查设备，当时就会更从容。',
    purpose: '讲完发生了什么，再说“如果重来会怎样”。'
  },
  3: {
    experience: '我觉得线上工具方便协作，但面对面交流依然重要。',
    grammar: 'while 让步从句 · 平衡观点',
    sentence: '<mark>While online tools make</mark> teamwork easier, face-to-face conversations <mark>still matter</mark>.',
    translation: '虽然线上工具让协作更容易，面对面交流仍然重要。',
    purpose: '讨论社会话题时，承认一面，再表达自己的判断。'
  }
};
const tabs = [...document.querySelectorAll('[data-part]')];
function showExample(part) {
  const example = examples[part];
  for (const key of ['experience', 'grammar', 'translation', 'purpose']) {
    document.getElementById(key).textContent = example[key];
  }
  // Fixed teaching examples; this markup never contains user input.
  document.getElementById('sentence').innerHTML = example.sentence;
  for (const tab of tabs) {
    const selected = tab.dataset.part === String(part);
    tab.setAttribute('aria-selected', String(selected));
    tab.tabIndex = selected ? 0 : -1;
  }
  document.getElementById('example-panel').setAttribute('aria-labelledby', `tab-part${part}`);
}
tabs.forEach((tab, index) => {
  tab.addEventListener('click', () => showExample(tab.dataset.part));
  tab.addEventListener('keydown', event => {
    const offsets = { ArrowLeft: -1, ArrowRight: 1 };
    if (!(event.key in offsets) && event.key !== 'Home' && event.key !== 'End') return;
    event.preventDefault();
    const next = event.key === 'Home' ? 0 : event.key === 'End' ? tabs.length - 1 : (index + offsets[event.key] + tabs.length) % tabs.length;
    showExample(tabs[next].dataset.part);
    tabs[next].focus();
  });
});
let toastTimer;
document.getElementById('copy-prompt').addEventListener('click', async () => {
  const toast = document.getElementById('toast');
  try {
    await navigator.clipboard.writeText(document.getElementById('skill-prompt').textContent);
    toast.textContent = '已复制，去新聊天里讲讲你自己吧。';
  } catch {
    toast.textContent = '暂时无法复制，请选中提示词手动复制。';
  }
  toast.classList.add('visible');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove('visible'), 3200);
});
