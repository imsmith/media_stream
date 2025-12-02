defmodule MediaStream.Media.AudioFile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "audio_files" do
    field :path, :string
    field :title, :string
    field :artist, :string
    field :album, :string
    field :duration_seconds, :integer
    field :file_type, :string
    field :file_size, :integer

    timestamps()
  end

  @doc false
  def changeset(audio_file, attrs) do
    audio_file
    |> cast(attrs, [:path, :title, :artist, :album, :duration_seconds, :file_type, :file_size])
    |> validate_required([:path])
    |> unique_constraint(:path)
  end
end
