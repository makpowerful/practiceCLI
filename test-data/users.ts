function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing env variable ${name}. Copy .env.example to .env and fill it in.`);
  }
  return value;
}

export const validUser = {
  email: requireEnv('APP_USER'),
  password: requireEnv('APP_PASSWORD'),
};
