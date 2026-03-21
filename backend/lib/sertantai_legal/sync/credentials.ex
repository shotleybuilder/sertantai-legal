defmodule SertantaiLegal.Sync.Credentials do
  @moduledoc """
  AES-256-CBC encryption/decryption for sync provider credentials.

  Each credential set gets a random IV. The encryption key is derived
  from SECRET_KEY_BASE via SHA-256.
  """

  @doc "Encrypt a credential map, returning {encrypted_base64, iv_base64}."
  def encrypt(credentials) when is_map(credentials) do
    iv = :crypto.strong_rand_bytes(16)
    key = encryption_key()
    plaintext = Jason.encode!(credentials)

    # PKCS7 pad to block size
    padded = pkcs7_pad(plaintext, 16)

    encrypted = :crypto.crypto_one_time(:aes_256_cbc, key, iv, padded, true)

    {Base.encode64(encrypted), Base.encode64(iv)}
  end

  @doc "Decrypt credentials from {encrypted_base64, iv_base64} to a map."
  def decrypt(encrypted_base64, iv_base64) do
    key = encryption_key()
    encrypted = Base.decode64!(encrypted_base64)
    iv = Base.decode64!(iv_base64)

    decrypted = :crypto.crypto_one_time(:aes_256_cbc, key, iv, encrypted, false)
    plaintext = pkcs7_unpad(decrypted)

    Jason.decode!(plaintext)
  end

  defp encryption_key do
    secret =
      Application.get_env(:sertantai_legal, SertantaiLegalWeb.Endpoint)[:secret_key_base] ||
        System.get_env("SECRET_KEY_BASE") ||
        raise "SECRET_KEY_BASE not configured"

    :crypto.hash(:sha256, secret)
  end

  defp pkcs7_pad(data, block_size) do
    pad_len = block_size - rem(byte_size(data), block_size)
    data <> :binary.copy(<<pad_len>>, pad_len)
  end

  defp pkcs7_unpad(data) do
    pad_len = :binary.last(data)
    :binary.part(data, 0, byte_size(data) - pad_len)
  end
end
