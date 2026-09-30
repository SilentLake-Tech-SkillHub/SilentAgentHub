(function (global) {
  'use strict';

  const ALLOWED_HOSTS = new Set([
    'openapi.alipay.com',
    'excashier.alipay.com',
    'openapi-sandbox.dl.alipaydev.com',
    'excashier-sandbox.dl.alipaydev.com'
  ]);

  function buildTrustedForm(paymentHtml) {
    const doc = new DOMParser().parseFromString(String(paymentHtml || ''), 'text/html');
    const source = doc.querySelector('form');
    if (!source) throw new Error('Alipay did not return a payment form');

    const action = new URL(source.getAttribute('action') || '', window.location.href);
    if (action.protocol !== 'https:' || !ALLOWED_HOSTS.has(action.hostname)) {
      throw new Error('Alipay form action is not an approved HTTPS host');
    }
    if ((source.getAttribute('method') || 'post').toLowerCase() !== 'post') {
      throw new Error('Alipay payment form must use POST');
    }

    const form = document.createElement('form');
    form.method = 'post';
    form.action = action.href;
    form.acceptCharset = 'UTF-8';
    source.querySelectorAll('input[name]').forEach((input) => {
      const clone = document.createElement('input');
      clone.type = 'hidden';
      clone.name = input.name;
      clone.value = input.value;
      form.appendChild(clone);
    });
    return form;
  }

  function submitPaymentHtml(paymentHtml) {
    const oldHost = document.getElementById('alipay-payment-form-host');
    if (oldHost) oldHost.remove();
    const host = document.createElement('div');
    host.id = 'alipay-payment-form-host';
    host.hidden = true;
    host.appendChild(buildTrustedForm(paymentHtml));
    document.body.appendChild(host);
    host.querySelector('form').submit();
  }

  async function start(options) {
    const response = await fetch(options.orderEndpoint, {
      method: 'POST',
      headers: options.headers || {},
      credentials: options.credentials || 'same-origin'
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok || !data.payment_html) {
      throw new Error(data.error || data.message || 'Failed to create Alipay order');
    }
    submitPaymentHtml(data.payment_html);
    return data;
  }

  global.AlipayCheckout = Object.freeze({
    start,
    submitPaymentHtml,
    buildTrustedForm
  });
})(window);
