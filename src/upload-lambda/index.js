'use strict';

const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const busboy = require('busboy');
const { v4: uuidv4 } = require('uuid');

const s3 = new S3Client({});

const BUCKET = process.env.S3_BUCKET;
const PREFIX = process.env.UPLOAD_PREFIX || 'uploads/';
const MAX_BYTES = parseInt(process.env.MAX_UPLOAD_BYTES || '4500000', 10);

const EXT = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/gif': 'gif',
  'image/webp': 'webp',
};

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

const respond = (status, body) => ({
  statusCode: status,
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify(body),
});

// Detecta el tipo real por los primeros bytes (no confiamos en el content-type del cliente)
function detectType(buf) {
  if (buf.length >= 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) {
    return 'image/jpeg';
  }
  if (
    buf.length >= 8 &&
    buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))
  ) {
    return 'image/png';
  }
  if (buf.length >= 6 && ['GIF87a', 'GIF89a'].includes(buf.subarray(0, 6).toString('latin1'))) {
    return 'image/gif';
  }
  if (
    buf.length >= 12 &&
    buf.subarray(0, 4).toString('latin1') === 'RIFF' &&
    buf.subarray(8, 12).toString('latin1') === 'WEBP'
  ) {
    return 'image/webp';
  }
  return null;
}

function parseMultipart(contentType, body) {
  return new Promise((resolve, reject) => {
    let bb;
    try {
      bb = busboy({
        headers: { 'content-type': contentType },
        limits: { files: 1, fileSize: MAX_BYTES },
      });
    } catch (err) {
      return reject(new HttpError(400, 'Multipart inválido'));
    }

    let result = null;
    let tooBig = false;

    bb.on('file', (_field, file, info) => {
      const chunks = [];
      file.on('data', (d) => chunks.push(d));
      file.on('limit', () => {
        tooBig = true;
      });
      file.on('end', () => {
        if (!result) result = { buffer: Buffer.concat(chunks), filename: info.filename };
      });
    });
    bb.on('error', () => reject(new HttpError(400, 'Multipart inválido')));
    bb.on('close', () => {
      if (tooBig) return reject(new HttpError(413, `La imagen supera el máximo de ${MAX_BYTES} bytes`));
      if (!result || result.buffer.length === 0) {
        return reject(new HttpError(400, 'Falta el archivo (campo multipart con la imagen)'));
      }
      return resolve(result);
    });

    bb.end(body);
  });
}

function parseJson(rawBody) {
  let payload;
  try {
    payload = JSON.parse(rawBody);
  } catch (err) {
    throw new HttpError(400, 'JSON inválido');
  }

  let b64 = payload.image || payload.data;
  if (typeof b64 !== 'string' || b64.length === 0) {
    throw new HttpError(400, 'Falta el campo "image" con la imagen en base64');
  }
  b64 = b64.replace(/^data:[^;]+;base64,/, '');

  // 4 caracteres base64 = 3 bytes; validamos antes de decodificar
  if (Math.floor((b64.length * 3) / 4) > MAX_BYTES) {
    throw new HttpError(413, `La imagen supera el máximo de ${MAX_BYTES} bytes`);
  }
  return { buffer: Buffer.from(b64, 'base64'), filename: payload.filename };
}

async function handle(event) {
  const headers = event.headers || {};
  const contentType = headers['content-type'] || headers['Content-Type'] || '';

  if (!event.body) throw new HttpError(400, 'Body vacío');

  const bodyBuf = Buffer.from(event.body, event.isBase64Encoded ? 'base64' : 'utf8');
  if (bodyBuf.length > MAX_BYTES + 1024 * 64) {
    throw new HttpError(413, `La imagen supera el máximo de ${MAX_BYTES} bytes`);
  }

  let image;
  if (contentType.toLowerCase().startsWith('multipart/form-data')) {
    image = await parseMultipart(contentType, bodyBuf);
  } else if (contentType.toLowerCase().startsWith('application/json')) {
    image = parseJson(bodyBuf.toString('utf8'));
  } else {
    throw new HttpError(415, 'Content-Type debe ser multipart/form-data o application/json');
  }

  if (image.buffer.length > MAX_BYTES) {
    throw new HttpError(413, `La imagen supera el máximo de ${MAX_BYTES} bytes`);
  }

  const type = detectType(image.buffer);
  if (!type) {
    throw new HttpError(415, 'Tipo no permitido. Solo jpg, png, gif y webp');
  }

  const id = uuidv4();
  const key = `${PREFIX}${id}.${EXT[type]}`;

  await s3.send(
    new PutObjectCommand({
      Bucket: BUCKET,
      Key: key,
      Body: image.buffer,
      ContentType: type,
    })
  );

  console.log(JSON.stringify({ msg: 'uploaded', key, size: image.buffer.length, type }));
  return respond(201, { id, key, contentType: type, size: image.buffer.length });
}

exports.handler = async (event) => {
  try {
    return await handle(event);
  } catch (err) {
    if (err instanceof HttpError) {
      return respond(err.status, { error: err.message });
    }
    console.error('unexpected error', err);
    return respond(500, { error: 'Error interno' });
  }
};
