defmodule MediaStream.Repo.Migrations.AddActiveDeviceToPlaybackStates do
  use Ecto.Migration

  def change do
    alter table(:playback_states) do
      add :active_player_id, :string
    end
  end
end
