import pulumi
import pulumiverse_doppler as doppler

def main():
    secrets = doppler.get_secrets(project="infrastructure", config_="prd")
    print("KEYS:", list(secrets.map.keys())[:5])

if __name__ == "__main__":
    import pulumi.runtime
    pulumi.runtime.run_in_stack(main)
