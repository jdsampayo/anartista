defmodule Anartista.Accounts do
  @moduledoc "Administrator accounts and revocable, seven-day sessions."

  import Ecto.Query, warn: false

  alias Anartista.Accounts.{User, UserToken}
  alias Anartista.Repo

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) and byte_size(password) >= 12 and
             byte_size(password) <= 72 do
    if String.valid?(email) and String.valid?(password) and
         :binary.match(password, <<0>>) == :nomatch do
      user = Repo.get_by(User, email: User.normalize_email(email))

      if user && Bcrypt.verify_pass(password, user.hashed_password) do
        user
      else
        if is_nil(user), do: Bcrypt.no_user_verify()
        nil
      end
    else
      no_user()
    end
  end

  def get_user_by_email_and_password(_email, _password), do: no_user()

  def generate_user_session_token(%User{} = user) do
    token = :crypto.strong_rand_bytes(32)
    Repo.insert!(%UserToken{token: hash_token(token), user_id: user.id})
    token
  end

  def get_user_by_session_token(token) when is_binary(token) and byte_size(token) == 32 do
    hashed_token = hash_token(token)

    Repo.one(
      from(session in UserToken,
        join: user in assoc(session, :user),
        where:
          session.token == ^hashed_token and
            session.inserted_at > ago(7, "day"),
        select: user
      )
    )
  end

  def get_user_by_session_token(_token), do: nil

  def delete_user_session_token(token) when is_binary(token) and byte_size(token) == 32 do
    hashed_token = hash_token(token)
    Repo.delete_all(from(session in UserToken, where: session.token == ^hashed_token))
    :ok
  end

  def delete_user_session_token(_token), do: :ok

  defp hash_token(token), do: :crypto.hash(:sha256, token)

  defp no_user do
    Bcrypt.no_user_verify()
    nil
  end
end
