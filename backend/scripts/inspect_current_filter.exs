alias SertantaiLegal.Sync.{Credentials, SyncConfiguration}
alias SertantaiLegal.Sync.Providers.Baserow, as: BaserowProvider

{:ok, sc} = Ash.get(SyncConfiguration, "90b9c916-e06b-48ff-861f-065f3778fd7a")
creds = Credentials.decrypt(sc.encrypted_credentials, sc.credentials_iv)
config = %{"base_url" => sc.target_config["base_url"], "credentials" => creds}
{:ok, config} = BaserowProvider.authenticate(config)

headers = [{"Authorization", "JWT #{config["jwt"]}"}, {"Content-Type", "application/json"}]
base = config["base_url"]

{:ok, %{body: ds_list}} = Req.get("#{base}/api/builder/page/1073284/data-sources/",
  headers: headers, receive_timeout: 15_000)
duties_ds = Enum.find(ds_list, fn d -> d["name"] == "Duties" end)
IO.inspect(duties_ds["filters"], pretty: true, limit: :infinity)
