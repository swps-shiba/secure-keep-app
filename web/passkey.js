(function () {
  const envelopeKey = 'secure_keep_passkey_envelope_v1';
  const encoder = new TextEncoder();

  function randomBytes(length) {
    const bytes = new Uint8Array(length);
    crypto.getRandomValues(bytes);
    return bytes;
  }

  function toBase64Url(bytes) {
    let binary = '';
    bytes.forEach((byte) => {
      binary += String.fromCharCode(byte);
    });
    return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
  }

  function fromBase64Url(value) {
    const base64 = value.replace(/-/g, '+').replace(/_/g, '/');
    const binary = atob(base64 + '='.repeat((4 - (base64.length % 4)) % 4));
    return Uint8Array.from(binary, (character) => character.charCodeAt(0));
  }

  function fromBase64(value) {
    return Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
  }

  function toBase64(bytes) {
    let binary = '';
    bytes.forEach((byte) => {
      binary += String.fromCharCode(byte);
    });
    return btoa(binary);
  }

  function assertAvailable() {
    if (!window.isSecureContext || !navigator.credentials || !window.PublicKeyCredential) {
      throw new Error('このブラウザーでは安全なパスキーが利用できません');
    }
  }

  async function deriveAesKey(prfOutput, salt) {
    const material = await crypto.subtle.importKey('raw', prfOutput, 'HKDF', false, ['deriveKey']);
    return crypto.subtle.deriveKey(
      { name: 'HKDF', hash: 'SHA-256', salt, info: encoder.encode('Secure Keep vault key v1') },
      material,
      { name: 'AES-GCM', length: 256 },
      false,
      ['encrypt', 'decrypt'],
    );
  }

  async function getPrfOutput(credential) {
    const first = credential.getClientExtensionResults()?.prf?.results?.first;
    if (!first) {
      throw new Error('この認証器はパスキー鍵保護（PRF）に対応していません');
    }
    return new Uint8Array(first);
  }

  async function requestPrf(salt, replaceExisting) {
    assertAvailable();
    const previous = localStorage.getItem(envelopeKey);
    const credentialId = replaceExisting || !previous
      ? null
      : JSON.parse(previous).credentialId;
    if (!credentialId) {
      const userId = randomBytes(32);
      const credential = await navigator.credentials.create({
        publicKey: {
          challenge: randomBytes(32),
          rp: { name: 'Secure Keep', id: location.hostname },
          user: {
            id: userId,
            name: 'secure-keep-vault',
            displayName: 'Secure Keep vault',
          },
          pubKeyCredParams: [
            { type: 'public-key', alg: -7 },
            { type: 'public-key', alg: -257 },
          ],
          authenticatorSelection: {
            authenticatorAttachment: 'platform',
            residentKey: 'required',
            userVerification: 'required',
          },
          timeout: 60000,
          extensions: { prf: { eval: { first: salt } } },
        },
      });
      if (!credential) {
        throw new Error('パスキーの登録がキャンセルされました');
      }
      return {
        output: await getPrfOutput(credential),
        credentialId: toBase64Url(new Uint8Array(credential.rawId)),
      };
    }

    const credential = await navigator.credentials.get({
      publicKey: {
        challenge: randomBytes(32),
        rpId: location.hostname,
        allowCredentials: [{
          type: 'public-key',
          id: fromBase64Url(credentialId),
        }],
        userVerification: 'required',
        timeout: 60000,
        extensions: { prf: { eval: { first: salt } } },
      },
    });
    if (!credential) {
      throw new Error('パスキーによる本人確認が完了しませんでした');
    }
    return {
      output: await getPrfOutput(credential),
      credentialId,
    };
  }

  window.secureKeepPasskeyHasKey = function () {
    const stored = localStorage.getItem(envelopeKey);
    if (!stored) {
      return false;
    }
    const envelope = JSON.parse(stored);
    return envelope.version === 1 && Boolean(
      envelope.credentialId && envelope.salt && envelope.iv && envelope.ciphertext,
    );
  };

  window.secureKeepPasskeyProtectKey = async function (keyBase64, replaceExisting) {
    const previous = localStorage.getItem(envelopeKey);
    const salt = !replaceExisting && previous
      ? fromBase64Url(JSON.parse(previous).salt)
      : randomBytes(32);
    const { output, credentialId } = await requestPrf(salt, replaceExisting);
    const key = await deriveAesKey(output, salt);
    const iv = randomBytes(12);
    const encrypted = await crypto.subtle.encrypt(
      { name: 'AES-GCM', iv },
      key,
      fromBase64(keyBase64),
    );
    localStorage.setItem(envelopeKey, JSON.stringify({
      version: 1,
      credentialId,
      salt: toBase64Url(salt),
      iv: toBase64Url(iv),
      ciphertext: toBase64Url(new Uint8Array(encrypted)),
    }));
    return true;
  };

  window.secureKeepPasskeyUnlockKey = async function () {
    assertAvailable();
    const stored = localStorage.getItem(envelopeKey);
    if (!stored) {
      throw new Error('このブラウザーに保護された暗号鍵がありません');
    }
    const envelope = JSON.parse(stored);
    if (envelope.version !== 1) {
      throw new Error('保護された暗号鍵の形式に対応していません');
    }
    const salt = fromBase64Url(envelope.salt || '');
    const iv = fromBase64Url(envelope.iv || '');
    const encrypted = fromBase64Url(envelope.ciphertext || '');
    if (salt.length !== 32 || iv.length !== 12 || encrypted.length < 32) {
      throw new Error('このブラウザーに保護された暗号鍵がありません');
    }
    const { output } = await requestPrf(salt, false);
    const key = await deriveAesKey(output, salt);
    const decrypted = await crypto.subtle.decrypt({ name: 'AES-GCM', iv }, key, encrypted);
    return toBase64(new Uint8Array(decrypted));
  };

  window.secureKeepPasskeyClear = function () {
    localStorage.removeItem(envelopeKey);
  };
})();
