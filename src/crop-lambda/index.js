'use strict';

const { S3Client, GetObjectCommand, PutObjectCommand } = require('@aws-sdk/client-s3');
const sharp = require('sharp');

const s3 = new S3Client({});

const BUCKET = process.env.S3_BUCKET;
const PROCESSED_PREFIX = process.env.PROCESSED_PREFIX || 'processed/';
const SIZE = 40;

// Máscara circular: lo que queda fuera del círculo pasa a transparente
const CIRCLE_MASK = Buffer.from(
  `<svg width="${SIZE}" height="${SIZE}" xmlns="http://www.w3.org/2000/svg">` +
    `<circle cx="${SIZE / 2}" cy="${SIZE / 2}" r="${SIZE / 2}" fill="#fff"/></svg>`
);

async function processS3Record(record) {
  const bucket = record.s3.bucket.name;
  // Las keys llegan URL-encoded en las notificaciones de S3 (espacios como "+")
  const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));

  if (bucket !== BUCKET) throw new Error(`Bucket inesperado: ${bucket}`);
  if (!key.startsWith('uploads/')) {
    console.log(JSON.stringify({ msg: 'skip, not in uploads/', key }));
    return;
  }

  const obj = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
  const input = Buffer.from(await obj.Body.transformToByteArray());

  const output = await sharp(input)
    .resize(SIZE, SIZE, { fit: 'cover' })
    .ensureAlpha()
    .composite([{ input: CIRCLE_MASK, blend: 'dest-in' }])
    .png()
    .toBuffer();

  const base = key.split('/').pop().replace(/\.[^.]+$/, '');
  const outKey = `${PROCESSED_PREFIX}${base}_circular.png`;

  await s3.send(
    new PutObjectCommand({
      Bucket: bucket,
      Key: outKey,
      Body: output,
      ContentType: 'image/png',
    })
  );

  console.log(JSON.stringify({ msg: 'processed', from: key, to: outKey }));
}

exports.handler = async (event) => {
  const batchItemFailures = [];

  for (const message of event.Records) {
    try {
      const body = JSON.parse(message.body);

      // S3 envía un evento de prueba al configurar la notificación
      if (body.Event === 's3:TestEvent') continue;

      for (const record of body.Records || []) {
        await processS3Record(record);
      }
    } catch (err) {
      console.error(JSON.stringify({ msg: 'failed', messageId: message.messageId, error: err.message }));
      batchItemFailures.push({ itemIdentifier: message.messageId });
    }
  }

  // Solo los mensajes que fallaron vuelven a la cola (ReportBatchItemFailures)
  return { batchItemFailures };
};
