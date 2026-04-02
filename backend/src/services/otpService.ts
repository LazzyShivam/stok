import prisma from '../config/database';

const OTP_EXPIRY_MINUTES = parseInt(process.env.OTP_EXPIRY_MINUTES || '5', 10);
const OTP_LENGTH = parseInt(process.env.OTP_LENGTH || '6', 10);
const DEV_OTP_BYPASS = process.env.DEV_OTP_BYPASS === 'true';

export const generateOTP = (): string => {
  if (DEV_OTP_BYPASS) return '123456';
  const digits = '0123456789';
  let otp = '';
  for (let i = 0; i < OTP_LENGTH; i++) {
    otp += digits[Math.floor(Math.random() * digits.length)];
  }
  return otp;
};

export const sendOTP = async (phone: string): Promise<string> => {
  // Invalidate existing OTPs for this phone
  await prisma.otpStore.updateMany({
    where: { phone, used: false },
    data: { used: true },
  });

  const otp = generateOTP();
  const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);

  await prisma.otpStore.create({ data: { phone, otp, expiresAt } });

  // In production, integrate Twilio here:
  // const client = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
  // await client.messages.create({ body: `Your Stok OTP is: ${otp}`, from: process.env.TWILIO_PHONE_NUMBER, to: phone });

  console.log(`[OTP] Phone: ${phone} OTP: ${otp}`); // Development only
  return otp;
};

export const verifyOTP = async (phone: string, otp: string): Promise<boolean> => {
  const record = await prisma.otpStore.findFirst({
    where: { phone, otp, used: false, expiresAt: { gt: new Date() } },
    orderBy: { createdAt: 'desc' },
  });

  if (!record) return false;

  await prisma.otpStore.update({ where: { id: record.id }, data: { used: true } });
  return true;
};
