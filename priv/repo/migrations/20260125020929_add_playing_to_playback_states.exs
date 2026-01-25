defmodule MediaStream.Repo.Migrations.AddPlayingToPlaybackStates do
  use Ecto.Migration

  def change do
    alter table(:playback_states) do
      add :playing, :boolean, default: false, null: false
    end
  end
end
