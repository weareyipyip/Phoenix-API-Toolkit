defmodule PhoenixApiToolkit.Ecto.ValidatorsTest do
  use ExUnit.Case, async: true

  import PhoenixApiToolkit.Ecto.Validators
  import Ecto.Changeset

  @signatures %{
    ("89504E470D0A1A0A" |> Base.decode16!()) => "image/png",
    &__MODULE__.is_valid_text/1 => "text/plain"
  }
  @pdf_signature "255044462D" |> Base.decode16!()
  @png_signature "89504E470D0A1A0A" |> Base.decode16!()
  @png_file "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
  @gif_file "R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=="
  @txt_file "some text" |> Base.encode64()
  @schema %{
    first_name: :string,
    last_name: :string,
    last_name_prefix: :string,
    order_by: :string,
    file: :string,
    mime_type: :string
  }
  @orderables ~w(first_name last_name) |> MapSet.new()

  def is_valid_text(binary), do: String.starts_with?(binary, "some")

  def changeset(changes \\ %{}) do
    {%{}, @schema} |> cast(changes, [:first_name, :last_name, :order_by, :file])
  end

  doctest PhoenixApiToolkit.Ecto.Validators

  test "validate_upload passes through no-change" do
    assert changeset() |> validate_upload(:file, @pdf_signature) == changeset()
  end
end
