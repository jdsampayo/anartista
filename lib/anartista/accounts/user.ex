defmodule Anartista.Accounts.User do
  use Ecto.Schema

  import Ecto.Changeset

  schema "users" do
    field(:email, :string)
    field(:password, :string, virtual: true, redact: true)
    field(:hashed_password, :string, redact: true)

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password], empty_values: [])
    |> update_change(:email, fn email ->
      if is_binary(email), do: normalize_email(email), else: email
    end)
    |> validate_required([:email, :password])
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/,
      message: "must be a valid email address"
    )
    |> validate_length(:email, max: 160)
    |> unique_constraint(:email)
    |> validate_password()
    |> hash_password()
  end

  def normalize_email(email), do: email |> String.trim() |> String.downcase()

  defp validate_password(changeset) do
    validate_change(changeset, :password, fn :password, password ->
      cond do
        not String.valid?(password) -> [password: "must be valid UTF-8"]
        :binary.match(password, <<0>>) != :nomatch -> [password: "must not contain null bytes"]
        byte_size(password) < 12 -> [password: "must be at least 12 bytes"]
        byte_size(password) > 72 -> [password: "must be at most 72 bytes"]
        true -> []
      end
    end)
  end

  defp hash_password(%Ecto.Changeset{valid?: true} = changeset) do
    case get_change(changeset, :password) do
      password when is_binary(password) ->
        changeset
        |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
        |> delete_change(:password)

      _ ->
        changeset
    end
  end

  defp hash_password(changeset), do: changeset
end
