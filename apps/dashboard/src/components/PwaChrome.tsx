import { useEffect, useState } from "react";
import { useRegisterSW } from "virtual:pwa-register/react";

type BeforeInstallPromptEvent = Event & { prompt: () => Promise<void> };

/** Update prompt (skipWaiting after confirm) + install affordance. */
export function PwaChrome() {
  const {
    needRefresh: [needRefresh, setNeedRefresh],
    updateServiceWorker,
  } = useRegisterSW({ immediate: true });
  const [installEvt, setInstallEvt] = useState<BeforeInstallPromptEvent | null>(null);

  useEffect(() => {
    const onBip = (e: Event) => {
      e.preventDefault();
      setInstallEvt(e as BeforeInstallPromptEvent);
    };
    window.addEventListener("beforeinstallprompt", onBip);
    return () => window.removeEventListener("beforeinstallprompt", onBip);
  }, []);

  if (!needRefresh && !installEvt) return null;

  return (
    <div className="pwa-toast" role="status">
      {needRefresh ? (
        <>
          <span>Update ready. Reload when you’re between lessons.</span>
          <button
            className="btn sm primary"
            onClick={() => {
              void updateServiceWorker(true);
              setNeedRefresh(false);
            }}
          >
            Reload
          </button>
          <button className="btn sm" onClick={() => setNeedRefresh(false)}>
            Later
          </button>
        </>
      ) : (
        <>
          <span>Install LicenseLogger on this device</span>
          <button
            className="btn sm primary"
            onClick={() => {
              if (installEvt) void installEvt.prompt().then(() => setInstallEvt(null));
            }}
          >
            Install
          </button>
          <button className="btn sm" onClick={() => setInstallEvt(null)}>
            Not now
          </button>
        </>
      )}
    </div>
  );
}
