defmodule Anartista.AccountsTest do
  use Anartista.DataCase, async: true

  alias Anartista.Accounts
  alias Anartista.Accounts.{User, UserToken}

  @password "a secure password"
  @email "admin@example.com"

  defp create_user do
    {:ok, user} = Accounts.create_user(%{email: @email, password: @password})
    user
  end

  test "stores only a hash and discards virtual plaintext" do
    {:ok, user} =
      Accounts.create_user(%{
        email: "  ADMIN@Example.COM  ",
        password: @password,
        hashed_password: "attacker-supplied-hash"
      })

    assert user.email == @email
    assert user.password == nil
    assert user.hashed_password != @password
    assert user.hashed_password != "attacker-supplied-hash"
    assert Bcrypt.verify_pass(@password, user.hashed_password)
    assert Repo.get!(User, user.id).password == nil
    refute inspect(user) =~ user.hashed_password
    refute inspect(user) =~ @password
  end

  test "normalizes identities and rejects duplicates without replacing credentials" do
    original = create_user()

    assert {:error, changeset} =
             Accounts.create_user(%{email: " ADMIN@EXAMPLE.COM ", password: "different password"})

    assert Map.has_key?(errors_on(changeset), :email)
    assert Accounts.get_user_by_email_and_password(@email, @password).id == original.id
    assert Accounts.get_user_by_email_and_password(@email, "different password") == nil
  end

  test "requires an email and valid password before hashing" do
    for attrs <- [
          %{email: nil, password: @password},
          %{email: "not-an-email", password: @password},
          %{email: @email, password: nil},
          %{email: @email, password: ""},
          %{email: @email, password: @password <> <<0>> <> "ignored suffix"},
          %{email: @email, password: <<255>> <> @password},
          %{email: @email, password: 123}
        ] do
      assert {:error, changeset} = Accounts.create_user(attrs)
      refute Map.has_key?(changeset.changes, :hashed_password)
    end
  end

  test "enforces password byte boundaries without truncating multibyte passwords" do
    for password <- [
          String.duplicate("x", 11),
          String.duplicate("x", 73),
          String.duplicate("é", 37)
        ] do
      assert {:error, changeset} =
               Accounts.create_user(%{email: @email, password: password})

      assert Map.has_key?(errors_on(changeset), :password)
      refute Map.has_key?(changeset.changes, :hashed_password)
    end

    for {password, email} <- [
          {String.duplicate("x", 12), "minimum@example.com"},
          {String.duplicate("é", 36), "maximum@example.com"}
        ] do
      assert {:ok, user} = Accounts.create_user(%{email: email, password: password})
      assert Accounts.get_user_by_email_and_password(email, password).id == user.id
      assert Accounts.get_user_by_email_and_password(email, password <> "x") == nil
    end
  end

  test "validates normalized credentials and safely rejects malformed inputs" do
    user = create_user()
    assert Accounts.get_user_by_email_and_password(" ADMIN@EXAMPLE.COM ", @password).id == user.id
    assert Accounts.get_user_by_email_and_password(@email, @password <> <<0>> <> "suffix") == nil

    for {email, password} <- [
          {@email, "wrong password"},
          {"unknown@example.com", @password},
          {nil, @password},
          {123, @password},
          {[], @password},
          {<<255>>, @password},
          {@email, nil},
          {@email, %{}},
          {@email, ""},
          {@email, String.duplicate("x", 73)},
          {@email, <<255>> <> @password}
        ] do
      assert Accounts.get_user_by_email_and_password(email, password) == nil
    end
  end

  test "stores a token digest and authenticates only the raw token" do
    user = create_user()
    token = Accounts.generate_user_session_token(user)
    session = Repo.get_by!(UserToken, user_id: user.id)

    assert byte_size(token) == 32
    assert session.token == :crypto.hash(:sha256, token)
    refute session.token == token
    assert Accounts.get_user_by_session_token(token).id == user.id
    assert Accounts.get_user_by_session_token(session.token) == nil
  end

  test "rejects expired, revoked, unknown, and malformed session tokens" do
    user = create_user()
    expired = Accounts.generate_user_session_token(user)
    revoked = Accounts.generate_user_session_token(user)
    active = Accounts.generate_user_session_token(user)

    Repo.update_all(
      from(session in UserToken, where: session.token == ^:crypto.hash(:sha256, expired)),
      set: [inserted_at: NaiveDateTime.add(NaiveDateTime.utc_now(:second), -8, :day)]
    )

    assert Accounts.get_user_by_session_token(expired) == nil
    assert Accounts.delete_user_session_token(revoked) == :ok
    assert Accounts.delete_user_session_token(revoked) == :ok
    assert Accounts.get_user_by_session_token(revoked) == nil
    assert Accounts.get_user_by_session_token(active).id == user.id

    for token <- [
          nil,
          1,
          %{},
          [],
          "",
          String.duplicate("x", 31),
          String.duplicate("x", 33),
          :crypto.strong_rand_bytes(32)
        ] do
      assert Accounts.get_user_by_session_token(token) == nil
      assert Accounts.delete_user_session_token(token) == :ok
    end

    assert Accounts.get_user_by_session_token(active).id == user.id
  end

  test "deleting an administrator cascades to all sessions" do
    user = create_user()
    first = Accounts.generate_user_session_token(user)
    second = Accounts.generate_user_session_token(user)

    Repo.delete!(user)

    assert Repo.all(from(session in UserToken, where: session.user_id == ^user.id)) == []
    assert Accounts.get_user_by_session_token(first) == nil
    assert Accounts.get_user_by_session_token(second) == nil
  end
end
