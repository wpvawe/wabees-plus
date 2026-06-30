<?php
/**
 * Wabees — WhatsApp Business Automation Platform
 * Premium Marketing Website
 */
$domain = 'https://wabees.live';
$appDomain = 'https://api.wabees.live';
$webPortal = 'https://web.wabees.live';
$downloadPath = '/download/';
?><!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Wabees — WhatsApp Business Automation Platform</title>
<meta name="description" content="Automate your WhatsApp Business. AI-powered bots, shared team inbox, broadcast campaigns, and real-time analytics — all in one platform."/>
<meta property="og:title" content="Wabees — WhatsApp Business Automation"/>
<meta property="og:description" content="Turn WhatsApp into your most powerful sales and support channel."/>
<meta property="og:url" content="<?= $domain ?>"/>
<link rel="preconnect" href="https://fonts.googleapis.com"/>
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin/>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&family=Syne:wght@700;800&display=swap" rel="stylesheet"/>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css"/>
<style>
:root{
  --g: #25D366;
  --t: #128C7E;
  --d: #075E54;
  --bg: #080d14;
  --bg2: #0d1520;
  --card: rgba(255,255,255,.04);
  --border: rgba(255,255,255,.08);
  --border2: rgba(37,211,102,.2);
  --text: #f0f4f8;
  --muted: #7a8899;
  --font: 'Inter', system-ui, sans-serif;
}
*{margin:0;padding:0;box-sizing:border-box}
html{scroll-behavior:smooth}
body{
  background:var(--bg);
  color:var(--text);
  font-family:var(--font);
  line-height:1.6;
  overflow-x:hidden;
}

/* ── NOISE OVERLAY ── */
body::before{
  content:'';
  position:fixed;
  inset:0;
  background-image:url("data:image/svg+xml,%3Csvg viewBox='0 0 200 200' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='.04'/%3E%3C/svg%3E");
  pointer-events:none;
  z-index:0;
  opacity:.4;
}

/* ── SCROLLBAR ── */
::-webkit-scrollbar{width:4px}
::-webkit-scrollbar-track{background:var(--bg)}
::-webkit-scrollbar-thumb{background:var(--t);border-radius:4px}

/* ── NAV ── */
nav{
  position:fixed;
  top:0;left:0;right:0;
  z-index:1000;
  padding:0 5%;
  height:68px;
  display:flex;
  align-items:center;
  justify-content:space-between;
  background:rgba(8,13,20,.8);
  backdrop-filter:blur(20px);
  border-bottom:1px solid var(--border);
  transition:all .3s;
}
.nav-logo{
  display:flex;align-items:center;gap:10px;
  text-decoration:none;
}
.nav-logo-icon{
  width:36px;height:36px;
  background:linear-gradient(135deg,var(--g),var(--t));
  border-radius:10px;
  display:flex;align-items:center;justify-content:center;
  font-size:18px;
  box-shadow:0 0 20px rgba(37,211,102,.3);
}
.nav-logo-text{
  font-family:'Syne',sans-serif;
  font-size:1.3rem;
  font-weight:800;
  color:#fff;
  letter-spacing:-.3px;
}
.nav-links{
  display:flex;align-items:center;gap:2rem;
  list-style:none;
}
.nav-links a{
  color:var(--muted);
  text-decoration:none;
  font-size:.875rem;
  font-weight:500;
  transition:color .2s;
}
.nav-links a:hover{color:var(--text)}
.nav-ctas{display:flex;gap:.75rem}
.btn{
  display:inline-flex;align-items:center;gap:.4rem;
  padding:.6rem 1.2rem;
  border-radius:8px;
  font-size:.875rem;
  font-weight:600;
  cursor:pointer;
  text-decoration:none;
  transition:all .2s;
  border:none;
  white-space:nowrap;
}
.btn-ghost{
  background:transparent;
  color:var(--text);
  border:1px solid var(--border);
}
.btn-ghost:hover{background:rgba(255,255,255,.06);border-color:rgba(255,255,255,.2)}
.btn-primary{
  background:linear-gradient(135deg,var(--g),var(--t));
  color:#fff;
  box-shadow:0 4px 20px rgba(37,211,102,.25);
}
.btn-primary:hover{
  transform:translateY(-1px);
  box-shadow:0 6px 28px rgba(37,211,102,.4);
}
.btn-lg{
  padding:.85rem 2rem;
  font-size:1rem;
  border-radius:10px;
}
.btn-xl{
  padding:1rem 2.4rem;
  font-size:1.05rem;
  border-radius:12px;
}

/* ── HERO ── */
.hero{
  min-height:100vh;
  display:flex;
  flex-direction:column;
  align-items:center;
  justify-content:center;
  text-align:center;
  padding:120px 5% 80px;
  position:relative;
  overflow:hidden;
}
.hero-bg{
  position:absolute;
  inset:0;
  background:
    radial-gradient(ellipse 80% 60% at 50% -10%,rgba(37,211,102,.12) 0%,transparent 60%),
    radial-gradient(ellipse 60% 40% at 80% 50%,rgba(18,140,126,.08) 0%,transparent 50%),
    radial-gradient(ellipse 40% 30% at 20% 80%,rgba(7,94,84,.1) 0%,transparent 50%);
  pointer-events:none;
}
.hero-grid{
  position:absolute;
  inset:0;
  background-image:
    linear-gradient(rgba(37,211,102,.04) 1px,transparent 1px),
    linear-gradient(90deg,rgba(37,211,102,.04) 1px,transparent 1px);
  background-size:60px 60px;
  mask-image:radial-gradient(ellipse 80% 80% at 50% 50%,black 20%,transparent 100%);
  pointer-events:none;
}
.hero-eyebrow{
  display:inline-flex;
  align-items:center;
  gap:.5rem;
  background:rgba(37,211,102,.08);
  border:1px solid rgba(37,211,102,.2);
  color:var(--g);
  font-size:.8rem;
  font-weight:600;
  letter-spacing:.06em;
  text-transform:uppercase;
  padding:.45rem 1rem;
  border-radius:100px;
  margin-bottom:2rem;
}
.hero-eyebrow span{
  width:6px;height:6px;
  background:var(--g);
  border-radius:50%;
  animation:pulse-dot 2s infinite;
}
@keyframes pulse-dot{0%,100%{opacity:1;transform:scale(1)}50%{opacity:.5;transform:scale(.7)}}
.hero h1{
  font-family:'Syne',sans-serif;
  font-size:clamp(2.8rem,6vw,5rem);
  font-weight:800;
  line-height:1.08;
  letter-spacing:-2px;
  max-width:780px;
  color:#fff;
  margin-bottom:1.5rem;
}
.hero h1 .highlight{
  background:linear-gradient(135deg,var(--g) 0%,#a8ff78 50%,var(--t) 100%);
  -webkit-background-clip:text;
  -webkit-text-fill-color:transparent;
  background-clip:text;
}
.hero-sub{
  font-size:1.15rem;
  color:var(--muted);
  max-width:520px;
  line-height:1.75;
  margin-bottom:2.5rem;
}
.hero-ctas{
  display:flex;
  align-items:center;
  gap:1rem;
  flex-wrap:wrap;
  justify-content:center;
  margin-bottom:3.5rem;
}
.hero-trust{
  display:flex;
  align-items:center;
  gap:1.5rem;
  flex-wrap:wrap;
  justify-content:center;
}
.trust-item{
  display:flex;
  align-items:center;
  gap:.4rem;
  font-size:.8rem;
  color:var(--muted);
}
.trust-item i{color:var(--g);font-size:.7rem}

/* ── PHONE MOCKUP ── */
.hero-visual{
  margin-top:4rem;
  position:relative;
  display:inline-block;
}
.phone-wrap{
  position:relative;
  width:280px;
  margin:0 auto;
}
.phone-frame{
  background:linear-gradient(160deg,#1a2433,#0d1520);
  border:1.5px solid rgba(255,255,255,.12);
  border-radius:40px;
  padding:18px 16px;
  box-shadow:
    0 60px 120px rgba(0,0,0,.6),
    0 0 0 1px rgba(255,255,255,.05),
    inset 0 1px 0 rgba(255,255,255,.08);
  position:relative;
  overflow:hidden;
}
.phone-notch{
  width:80px;height:26px;
  background:#0d1520;
  border-radius:0 0 18px 18px;
  margin:0 auto 14px;
  display:flex;
  align-items:center;
  justify-content:center;
  gap:5px;
}
.phone-notch-cam{
  width:8px;height:8px;
  background:#1a2433;
  border-radius:50%;
  border:1px solid rgba(255,255,255,.1);
}
.phone-screen{
  background:linear-gradient(180deg,#0a1929,#0d1f30);
  border-radius:26px;
  overflow:hidden;
  min-height:420px;
}
.wa-header{
  background:linear-gradient(135deg,var(--d),var(--t));
  padding:12px 14px;
  display:flex;
  align-items:center;
  gap:10px;
}
.wa-avatar{
  width:34px;height:34px;
  border-radius:50%;
  background:rgba(255,255,255,.2);
  display:flex;align-items:center;justify-content:center;
  font-size:14px;
  font-weight:700;
  color:#fff;
}
.wa-info{flex:1}
.wa-name{font-size:.8rem;font-weight:600;color:#fff}
.wa-status{font-size:.65rem;color:rgba(255,255,255,.7)}
.wa-body{padding:12px 10px;display:flex;flex-direction:column;gap:8px}
.wa-msg{
  max-width:80%;
  padding:8px 10px;
  border-radius:12px;
  font-size:.72rem;
  line-height:1.45;
}
.wa-msg-in{
  background:rgba(255,255,255,.07);
  color:rgba(255,255,255,.85);
  border-radius:12px 12px 12px 2px;
  align-self:flex-start;
}
.wa-msg-out{
  background:linear-gradient(135deg,rgba(37,211,102,.25),rgba(18,140,126,.2));
  color:rgba(255,255,255,.9);
  border-radius:12px 12px 2px 12px;
  align-self:flex-end;
}
.wa-time{font-size:.55rem;opacity:.5;margin-top:3px;text-align:right}
.wa-ai-badge{
  display:inline-flex;
  align-items:center;
  gap:3px;
  background:rgba(37,211,102,.1);
  color:var(--g);
  font-size:.55rem;
  font-weight:600;
  padding:2px 6px;
  border-radius:4px;
  margin-top:2px;
}
.typing-indicator{
  display:flex;
  align-items:center;
  gap:3px;
  padding:8px 10px;
  background:rgba(255,255,255,.07);
  border-radius:12px 12px 12px 2px;
  width:fit-content;
}
.typing-dot{
  width:5px;height:5px;
  background:var(--muted);
  border-radius:50%;
  animation:typing 1.4s infinite;
}
.typing-dot:nth-child(2){animation-delay:.2s}
.typing-dot:nth-child(3){animation-delay:.4s}
@keyframes typing{0%,80%,100%{transform:scale(.6);opacity:.4}40%{transform:scale(1);opacity:1}}
.glow-ring{
  position:absolute;
  inset:-40px;
  background:radial-gradient(ellipse at center,rgba(37,211,102,.08) 0%,transparent 70%);
  border-radius:50%;
  animation:glow-pulse 3s ease-in-out infinite;
  pointer-events:none;
}
@keyframes glow-pulse{0%,100%{opacity:.6;transform:scale(1)}50%{opacity:1;transform:scale(1.05)}}
.float-badge{
  position:absolute;
  background:rgba(13,21,32,.9);
  backdrop-filter:blur(20px);
  border:1px solid var(--border2);
  border-radius:14px;
  padding:10px 14px;
  display:flex;
  align-items:center;
  gap:8px;
  font-size:.78rem;
  font-weight:600;
  color:#fff;
  box-shadow:0 8px 32px rgba(0,0,0,.4);
  animation:float-bob 4s ease-in-out infinite;
  white-space:nowrap;
}
.float-badge i{color:var(--g);font-size:.9rem}
.float-badge-1{top:10%;right:-120px;animation-delay:0s}
.float-badge-2{bottom:25%;left:-130px;animation-delay:1.5s}
@keyframes float-bob{0%,100%{transform:translateY(0)}50%{transform:translateY(-8px)}}

/* ── STATS BAR ── */
.stats-section{
  padding:60px 5%;
  position:relative;
}
.stats-bar{
  max-width:1000px;
  margin:0 auto;
  display:grid;
  grid-template-columns:repeat(6,1fr);
  gap:1px;
  background:var(--border);
  border-radius:16px;
  overflow:hidden;
  border:1px solid var(--border);
}
.stat-item{
  background:var(--bg2);
  padding:2rem 1.5rem;
  text-align:center;
  transition:background .2s;
}
.stat-item:hover{background:rgba(37,211,102,.04)}
.stat-num{
  font-family:'Syne',sans-serif;
  font-size:1.9rem;
  font-weight:800;
  color:var(--g);
  line-height:1;
  margin-bottom:.3rem;
  display:flex;
  align-items:baseline;
  justify-content:center;
  gap:1px;
}
.stat-num .suffix{font-size:1.1rem;color:var(--t)}
.stat-label{font-size:.72rem;color:var(--muted);font-weight:500;text-transform:uppercase;letter-spacing:.06em}
.stat-live{
  display:inline-flex;
  align-items:center;
  gap:4px;
  font-size:.6rem;
  color:var(--g);
  margin-top:.3rem;
}
.live-dot{
  width:5px;height:5px;
  background:var(--g);
  border-radius:50%;
  animation:pulse-dot 2s infinite;
}

/* ── SECTION COMMON ── */
section{padding:100px 5%;position:relative}
.section-label{
  display:inline-flex;
  align-items:center;
  gap:.4rem;
  font-size:.75rem;
  font-weight:700;
  letter-spacing:.1em;
  text-transform:uppercase;
  color:var(--g);
  margin-bottom:1rem;
}
.section-label::before{
  content:'';
  width:20px;height:2px;
  background:var(--g);
  border-radius:2px;
}
h2{
  font-family:'Syne',sans-serif;
  font-size:clamp(2rem,3.5vw,2.8rem);
  font-weight:800;
  color:#fff;
  line-height:1.15;
  letter-spacing:-1px;
}
.section-sub{
  font-size:1rem;
  color:var(--muted);
  max-width:520px;
  line-height:1.75;
  margin-top:.8rem;
}

/* ── FEATURES ── */
.features-section{background:var(--bg2)}
.features-section::before{
  content:'';
  position:absolute;
  inset:0;
  background:radial-gradient(ellipse 60% 40% at 0% 50%,rgba(37,211,102,.06) 0%,transparent 60%);
  pointer-events:none;
}
.features-inner{max-width:1180px;margin:0 auto}
.features-header{margin-bottom:4rem}
.features-grid{
  display:grid;
  grid-template-columns:repeat(3,1fr);
  gap:1.5px;
  background:var(--border);
  border-radius:20px;
  overflow:hidden;
  border:1px solid var(--border);
}
.feat-card{
  background:var(--bg2);
  padding:2.5rem;
  transition:background .3s;
  position:relative;
  overflow:hidden;
}
.feat-card::before{
  content:'';
  position:absolute;
  top:0;left:0;right:0;
  height:2px;
  background:linear-gradient(90deg,transparent,var(--g),transparent);
  opacity:0;
  transition:opacity .3s;
}
.feat-card:hover{background:rgba(37,211,102,.03)}
.feat-card:hover::before{opacity:1}
.feat-icon{
  width:48px;height:48px;
  border-radius:12px;
  background:rgba(37,211,102,.1);
  border:1px solid rgba(37,211,102,.2);
  display:flex;align-items:center;justify-content:center;
  font-size:1.2rem;
  color:var(--g);
  margin-bottom:1.5rem;
  transition:all .3s;
}
.feat-card:hover .feat-icon{
  background:linear-gradient(135deg,rgba(37,211,102,.2),rgba(18,140,126,.2));
  box-shadow:0 0 20px rgba(37,211,102,.2);
}
.feat-title{
  font-size:1rem;
  font-weight:700;
  color:#fff;
  margin-bottom:.6rem;
}
.feat-desc{
  font-size:.875rem;
  color:var(--muted);
  line-height:1.65;
}
.feat-tag{
  display:inline-flex;
  align-items:center;
  gap:.3rem;
  margin-top:1rem;
  font-size:.7rem;
  font-weight:600;
  color:var(--t);
  background:rgba(18,140,126,.1);
  padding:.25rem .7rem;
  border-radius:100px;
}

/* ── HOW IT WORKS ── */
.how-section{overflow:hidden}
.how-inner{max-width:1100px;margin:0 auto}
.how-steps{
  display:grid;
  grid-template-columns:repeat(3,1fr);
  gap:2rem;
  margin-top:4rem;
  position:relative;
}
.how-steps::before{
  content:'';
  position:absolute;
  top:36px;
  left:calc(16.66% + 36px);
  right:calc(16.66% + 36px);
  height:2px;
  background:linear-gradient(90deg,var(--g),var(--t));
  opacity:.3;
}
.how-step{text-align:center;padding:2rem}
.step-num{
  width:72px;height:72px;
  border-radius:50%;
  background:linear-gradient(135deg,rgba(37,211,102,.15),rgba(18,140,126,.15));
  border:2px solid rgba(37,211,102,.3);
  display:flex;align-items:center;justify-content:center;
  margin:0 auto 1.5rem;
  font-family:'Syne',sans-serif;
  font-size:1.6rem;
  font-weight:800;
  color:var(--g);
  position:relative;
  box-shadow:0 0 30px rgba(37,211,102,.1);
}
.step-icon{
  font-size:1.5rem;
  color:var(--g);
}
.step-title{
  font-size:1.05rem;
  font-weight:700;
  color:#fff;
  margin-bottom:.6rem;
}
.step-desc{
  font-size:.875rem;
  color:var(--muted);
  line-height:1.65;
}

/* ── AI SHOWCASE ── */
.ai-section{background:var(--bg2)}
.ai-inner{
  max-width:1100px;
  margin:0 auto;
  display:grid;
  grid-template-columns:1fr 1fr;
  gap:5rem;
  align-items:center;
}
.ai-visual{
  position:relative;
}
.ai-terminal{
  background:#080d14;
  border:1px solid var(--border);
  border-radius:16px;
  overflow:hidden;
  box-shadow:0 30px 80px rgba(0,0,0,.5);
}
.terminal-header{
  background:rgba(255,255,255,.04);
  border-bottom:1px solid var(--border);
  padding:12px 16px;
  display:flex;
  align-items:center;
  gap:6px;
}
.dot-r{width:12px;height:12px;border-radius:50%;background:#ff5f57}
.dot-y{width:12px;height:12px;border-radius:50%;background:#febc2e}
.dot-g{width:12px;height:12px;border-radius:50%;background:#28c840}
.terminal-title{
  flex:1;text-align:center;
  font-size:.75rem;
  color:var(--muted);
  font-weight:500;
}
.terminal-body{padding:1.5rem}
.log-line{
  display:flex;
  gap:.75rem;
  font-size:.78rem;
  font-family:'JetBrains Mono',monospace;
  margin-bottom:.7rem;
  line-height:1.5;
}
.log-time{color:var(--muted);min-width:48px}
.log-tag{
  padding:1px 6px;
  border-radius:4px;
  font-size:.65rem;
  font-weight:700;
  min-width:36px;
  text-align:center;
}
.tag-ai{background:rgba(37,211,102,.15);color:var(--g)}
.tag-msg{background:rgba(18,140,126,.15);color:var(--t)}
.tag-ok{background:rgba(40,200,64,.1);color:#28c840}
.tag-bot{background:rgba(254,188,46,.1);color:#febc2e}
.log-text{color:rgba(255,255,255,.75)}
.log-text .hl{color:var(--g)}
.cursor-blink{
  display:inline-block;
  width:8px;height:14px;
  background:var(--g);
  margin-left:2px;
  animation:blink .9s infinite;
  vertical-align:middle;
  border-radius:1px;
}
@keyframes blink{0%,100%{opacity:1}50%{opacity:0}}
.ai-features{display:flex;flex-direction:column;gap:1.2rem;margin-top:2.5rem}
.ai-feat{
  display:flex;
  align-items:flex-start;
  gap:1rem;
  padding:1rem 1.2rem;
  background:rgba(255,255,255,.02);
  border:1px solid var(--border);
  border-radius:12px;
  transition:all .2s;
}
.ai-feat:hover{
  background:rgba(37,211,102,.04);
  border-color:var(--border2);
}
.ai-feat-icon{
  width:36px;height:36px;
  border-radius:8px;
  background:rgba(37,211,102,.1);
  display:flex;align-items:center;justify-content:center;
  color:var(--g);
  font-size:.9rem;
  flex-shrink:0;
}
.ai-feat-text h4{
  font-size:.875rem;
  font-weight:600;
  color:#fff;
  margin-bottom:.2rem;
}
.ai-feat-text p{font-size:.8rem;color:var(--muted)}

/* ── PRICING ── */
.pricing-section{overflow:hidden}
.pricing-section::before{
  content:'';
  position:absolute;
  inset:0;
  background:radial-gradient(ellipse 50% 50% at 50% 0%,rgba(37,211,102,.07) 0%,transparent 60%);
  pointer-events:none;
}
.pricing-inner{max-width:1050px;margin:0 auto}
.pricing-header{text-align:center;margin-bottom:4rem}
.plans-grid{
  display:grid;
  grid-template-columns:1fr 1.08fr 1fr;
  gap:1.5rem;
  align-items:start;
}
.plan-card{
  background:var(--bg2);
  border:1px solid var(--border);
  border-radius:20px;
  padding:2.5rem;
  position:relative;
  transition:transform .2s,box-shadow .2s;
}
.plan-card:hover{
  transform:translateY(-4px);
  box-shadow:0 20px 60px rgba(0,0,0,.3);
}
.plan-card.popular{
  border-color:var(--g);
  background:linear-gradient(160deg,rgba(37,211,102,.06),rgba(18,140,126,.04));
  box-shadow:0 0 60px rgba(37,211,102,.1);
}
.plan-popular-badge{
  position:absolute;
  top:-14px;
  left:50%;
  transform:translateX(-50%);
  background:linear-gradient(135deg,var(--g),var(--t));
  color:#fff;
  font-size:.7rem;
  font-weight:700;
  padding:.35rem 1rem;
  border-radius:100px;
  white-space:nowrap;
  letter-spacing:.04em;
}
.plan-name{
  font-size:.8rem;
  font-weight:700;
  color:var(--g);
  text-transform:uppercase;
  letter-spacing:.08em;
  margin-bottom:.5rem;
}
.plan-price{
  font-family:'Syne',sans-serif;
  font-size:2.8rem;
  font-weight:800;
  color:#fff;
  line-height:1;
  margin-bottom:.3rem;
}
.plan-price sup{
  font-size:1.2rem;
  font-weight:600;
  vertical-align:top;
  margin-top:.5rem;
  display:inline-block;
  color:var(--muted);
}
.plan-price span{
  font-size:1rem;
  font-weight:400;
  color:var(--muted);
}
.plan-desc{
  font-size:.82rem;
  color:var(--muted);
  margin-bottom:2rem;
  padding-bottom:2rem;
  border-bottom:1px solid var(--border);
}
.plan-features{list-style:none;display:flex;flex-direction:column;gap:.75rem;margin-bottom:2rem}
.plan-features li{
  display:flex;
  align-items:flex-start;
  gap:.6rem;
  font-size:.84rem;
  color:var(--muted);
}
.plan-features li i{
  color:var(--g);
  font-size:.75rem;
  margin-top:.15rem;
  flex-shrink:0;
}
.plan-features li.dimmed{opacity:.4}
.plan-features li.dimmed i{color:var(--muted)}

/* ── TESTIMONIALS ── */
.testimonials-section{background:var(--bg2)}
.testimonials-inner{max-width:1100px;margin:0 auto}
.testimonials-header{text-align:center;margin-bottom:4rem}
.testi-grid{
  display:grid;
  grid-template-columns:repeat(3,1fr);
  gap:1.5rem;
}
.testi-card{
  background:rgba(255,255,255,.03);
  border:1px solid var(--border);
  border-radius:16px;
  padding:2rem;
  transition:all .2s;
}
.testi-card:hover{
  background:rgba(37,211,102,.04);
  border-color:var(--border2);
  transform:translateY(-2px);
}
.testi-stars{
  color:#f59e0b;
  font-size:.85rem;
  margin-bottom:1rem;
  letter-spacing:2px;
}
.testi-text{
  font-size:.9rem;
  color:rgba(255,255,255,.75);
  line-height:1.7;
  margin-bottom:1.5rem;
  font-style:italic;
}
.testi-author{display:flex;align-items:center;gap:.75rem}
.testi-avatar{
  width:40px;height:40px;
  border-radius:50%;
  background:linear-gradient(135deg,var(--g),var(--t));
  display:flex;align-items:center;justify-content:center;
  font-size:.95rem;
  font-weight:700;
  color:#fff;
  flex-shrink:0;
}
.testi-name{font-size:.875rem;font-weight:600;color:#fff}
.testi-biz{font-size:.75rem;color:var(--muted)}

/* ── CTA ── */
.cta-section{
  padding:100px 5%;
  text-align:center;
  position:relative;
  overflow:hidden;
}
.cta-section::before{
  content:'';
  position:absolute;
  inset:0;
  background:radial-gradient(ellipse 80% 60% at 50% 50%,rgba(37,211,102,.08) 0%,transparent 70%);
  pointer-events:none;
}
.cta-inner{max-width:680px;margin:0 auto;position:relative}
.cta-inner h2{
  font-size:clamp(2rem,4vw,3rem);
  margin-bottom:1.2rem;
}
.cta-inner p{
  font-size:1rem;
  color:var(--muted);
  margin-bottom:2.5rem;
  line-height:1.75;
}
.cta-btns{
  display:flex;
  gap:1rem;
  justify-content:center;
  flex-wrap:wrap;
}
.cta-secure{
  display:flex;
  align-items:center;
  justify-content:center;
  gap:1.5rem;
  margin-top:1.5rem;
  flex-wrap:wrap;
}
.cta-secure-item{
  display:flex;
  align-items:center;
  gap:.4rem;
  font-size:.78rem;
  color:var(--muted);
}
.cta-secure-item i{color:var(--g);font-size:.7rem}

/* ── FOOTER ── */
footer{
  background:var(--bg2);
  border-top:1px solid var(--border);
  padding:60px 5% 30px;
}
.footer-top{
  display:grid;
  grid-template-columns:1.5fr 1fr 1fr 1fr;
  gap:3rem;
  margin-bottom:3rem;
}
.footer-brand p{
  font-size:.85rem;
  color:var(--muted);
  line-height:1.7;
  margin-top:1rem;
  max-width:240px;
}
.footer-col h4{
  font-size:.8rem;
  font-weight:700;
  text-transform:uppercase;
  letter-spacing:.08em;
  color:var(--text);
  margin-bottom:1.2rem;
}
.footer-col ul{list-style:none;display:flex;flex-direction:column;gap:.7rem}
.footer-col ul a{
  font-size:.84rem;
  color:var(--muted);
  text-decoration:none;
  transition:color .2s;
}
.footer-col ul a:hover{color:var(--g)}
.footer-bottom{
  border-top:1px solid var(--border);
  padding-top:1.5rem;
  display:flex;
  align-items:center;
  justify-content:space-between;
  flex-wrap:wrap;
  gap:1rem;
}
.footer-copy{font-size:.8rem;color:var(--muted)}
.footer-badges{
  display:flex;
  gap:.75rem;
}
.footer-badge{
  display:flex;
  align-items:center;
  gap:.4rem;
  font-size:.7rem;
  color:var(--muted);
  background:rgba(255,255,255,.03);
  border:1px solid var(--border);
  padding:.3rem .7rem;
  border-radius:6px;
}
.footer-badge i{color:var(--g)}

/* ── WHATSAPP FAB ── */
.wa-fab{
  position:fixed;
  bottom:1.5rem;
  right:1.5rem;
  width:52px;height:52px;
  background:linear-gradient(135deg,var(--g),var(--t));
  border-radius:50%;
  display:flex;align-items:center;justify-content:center;
  font-size:1.4rem;
  color:#fff;
  text-decoration:none;
  box-shadow:0 8px 30px rgba(37,211,102,.4);
  z-index:900;
  transition:transform .2s,box-shadow .2s;
}
.wa-fab:hover{
  transform:scale(1.08);
  box-shadow:0 12px 40px rgba(37,211,102,.5);
}

/* ── ANIMATIONS ── */
.fade-up{
  opacity:0;
  transform:translateY(30px);
  transition:opacity .6s ease,transform .6s ease;
}
.fade-up.visible{opacity:1;transform:translateY(0)}

/* ── RESPONSIVE ── */
@media(max-width:900px){
  .stats-bar{grid-template-columns:repeat(3,1fr)}
  .features-grid{grid-template-columns:1fr 1fr}
  .how-steps{grid-template-columns:1fr}
  .how-steps::before{display:none}
  .ai-inner{grid-template-columns:1fr}
  .plans-grid{grid-template-columns:1fr}
  .testi-grid{grid-template-columns:1fr}
  .footer-top{grid-template-columns:1fr 1fr}
  .float-badge-1,.float-badge-2{display:none}
  nav .nav-links{display:none}
}
@media(max-width:600px){
  .stats-bar{grid-template-columns:repeat(2,1fr)}
  .features-grid{grid-template-columns:1fr}
  .plans-grid{grid-template-columns:1fr}
  .hero h1{font-size:2.4rem}
  .footer-top{grid-template-columns:1fr}
}
</style>
</head>
<body>

<!-- NAV -->
<nav>
  <a class="nav-logo" href="/">
    <div class="nav-logo-icon"><i class="fab fa-whatsapp" style="color:#fff"></i></div>
    <span class="nav-logo-text">Wabees</span>
  </a>
  <ul class="nav-links">
    <li><a href="#features">Features</a></li>
    <li><a href="#how">How it works</a></li>
    <li><a href="#ai">AI Bot</a></li>
    <li><a href="#pricing">Pricing</a></li>
  </ul>
  <div class="nav-ctas">
    <a href="<?= $webPortal ?>" class="btn btn-ghost"><i class="fas fa-sign-in-alt"></i> Login</a>
    <a href="<?= $downloadPath ?>" class="btn btn-primary"><i class="fas fa-download"></i> Download App</a>
  </div>
</nav>

<!-- HERO -->
<section class="hero">
  <div class="hero-bg"></div>
  <div class="hero-grid"></div>

  <div class="hero-eyebrow">
    <span></span>
    WhatsApp Business Automation Platform
  </div>

  <h1>
    Turn WhatsApp Into<br>
    Your <span class="highlight">Growth Engine</span>
  </h1>

  <p class="hero-sub">
    AI-powered bots, shared team inbox, broadcast campaigns, and real-time analytics — everything you need to scale on WhatsApp.
  </p>

  <div class="hero-ctas">
    <a href="<?= $downloadPath ?>" class="btn btn-primary btn-xl">
      <i class="fab fa-android"></i> Get the App Free
    </a>
    <a href="<?= $webPortal ?>" class="btn btn-ghost btn-xl">
      <i class="fas fa-globe"></i> Open Web Portal
    </a>
  </div>

  <div class="hero-trust">
    <div class="trust-item"><i class="fas fa-check-circle"></i> No credit card required</div>
    <div class="trust-item"><i class="fas fa-check-circle"></i> Setup in 5 minutes</div>
    <div class="trust-item"><i class="fas fa-check-circle"></i> WhatsApp Business API</div>
    <div class="trust-item"><i class="fas fa-check-circle"></i> 24/7 AI responses</div>
  </div>

  <!-- Phone Mockup -->
  <div class="hero-visual fade-up">
    <div class="phone-wrap">
      <div class="glow-ring"></div>
      <div class="phone-frame">
        <div class="phone-notch">
          <div class="phone-notch-cam"></div>
        </div>
        <div class="phone-screen">
          <div class="wa-header">
            <div class="wa-avatar">W</div>
            <div class="wa-info">
              <div class="wa-name">Wabees AI Bot</div>
              <div class="wa-status">● Online now</div>
            </div>
            <i class="fas fa-ellipsis-v" style="color:rgba(255,255,255,.6);font-size:.8rem"></i>
          </div>
          <div class="wa-body">
            <div class="wa-msg wa-msg-in">
              Hi! I want to know your prices 💬
              <div class="wa-time">09:41</div>
            </div>
            <div class="typing-indicator">
              <div class="typing-dot"></div>
              <div class="typing-dot"></div>
              <div class="typing-dot"></div>
            </div>
            <div class="wa-msg wa-msg-out">
              Hello! 👋 Our basic plan starts at Rs. 2,999/month. Would you like to see the full details?
              <div class="wa-ai-badge"><i class="fas fa-robot"></i> AI Reply</div>
              <div class="wa-time">09:41 ✓✓</div>
            </div>
            <div class="wa-msg wa-msg-in">
              Yes please! What's included?
              <div class="wa-time">09:42</div>
            </div>
            <div class="wa-msg wa-msg-out">
              ✅ Unlimited messages<br>
              ✅ AI bot + broadcast<br>
              ✅ 3 team agents<br><br>
              Want to schedule a demo?
              <div class="wa-ai-badge"><i class="fas fa-robot"></i> AI Reply</div>
              <div class="wa-time">09:42 ✓✓</div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="float-badge float-badge-1">
      <i class="fas fa-bolt"></i>
      <div>
        <div style="font-size:.65rem;color:var(--muted)">Response time</div>
        <div style="font-size:.85rem">&lt; 2 seconds</div>
      </div>
    </div>
    <div class="float-badge float-badge-2">
      <i class="fas fa-users"></i>
      <div>
        <div style="font-size:.65rem;color:var(--muted)">Active users</div>
        <div style="font-size:.85rem">Growing daily</div>
      </div>
    </div>
  </div>
</section>

<!-- LIVE STATS -->
<div class="stats-section fade-up">
  <div class="stats-bar">
    <div class="stat-item">
      <div class="stat-num"><span id="s-msgs">—</span></div>
      <div class="stat-label">Messages Sent</div>
      <div class="stat-live"><span class="live-dot"></span> Live</div>
    </div>
    <div class="stat-item">
      <div class="stat-num"><span id="s-users">—</span></div>
      <div class="stat-label">Active Users</div>
      <div class="stat-live"><span class="live-dot"></span> Live</div>
    </div>
    <div class="stat-item">
      <div class="stat-num"><span id="s-agents">—</span></div>
      <div class="stat-label">Team Agents</div>
      <div class="stat-live"><span class="live-dot"></span> Live</div>
    </div>
    <div class="stat-item">
      <div class="stat-num"><span id="s-contacts">—</span></div>
      <div class="stat-label">Contacts</div>
      <div class="stat-live"><span class="live-dot"></span> Live</div>
    </div>
    <div class="stat-item">
      <div class="stat-num"><span id="s-bots">—</span></div>
      <div class="stat-label">Active Bots</div>
      <div class="stat-live"><span class="live-dot"></span> Live</div>
    </div>
    <div class="stat-item">
      <div class="stat-num"><span id="s-convs">—</span></div>
      <div class="stat-label">Conversations</div>
      <div class="stat-live"><span class="live-dot"></span> Live</div>
    </div>
  </div>
</div>

<!-- FEATURES -->
<section class="features-section" id="features">
  <div class="features-inner">
    <div class="features-header fade-up">
      <div class="section-label">Everything you need</div>
      <h2>Built for Serious<br>WhatsApp Businesses</h2>
      <p class="section-sub">From solo entrepreneurs to enterprise teams — Wabees gives you tools that actually grow your business.</p>
    </div>
    <div class="features-grid fade-up">
      <div class="feat-card">
        <div class="feat-icon"><i class="fas fa-users"></i></div>
        <div class="feat-title">Shared Team Inbox</div>
        <div class="feat-desc">Your entire team manages WhatsApp conversations from one place. Assign chats, add notes, and never miss a message.</div>
        <div class="feat-tag"><i class="fas fa-star"></i> Most popular</div>
      </div>
      <div class="feat-card">
        <div class="feat-icon"><i class="fas fa-robot"></i></div>
        <div class="feat-title">AI-Powered Bot</div>
        <div class="feat-desc">Train your own AI on your business data. It handles FAQs, qualifies leads, and responds instantly — 24/7, in any language.</div>
        <div class="feat-tag"><i class="fas fa-fire"></i> Trending</div>
      </div>
      <div class="feat-card">
        <div class="feat-icon"><i class="fas fa-broadcast-tower"></i></div>
        <div class="feat-title">Broadcast Campaigns</div>
        <div class="feat-desc">Send targeted bulk messages to segmented lists. Perfect for promotions, updates, and re-engagement campaigns.</div>
        <div class="feat-tag"><i class="fas fa-chart-line"></i> High ROI</div>
      </div>
      <div class="feat-card">
        <div class="feat-icon"><i class="fas fa-file-alt"></i></div>
        <div class="feat-title">Message Templates</div>
        <div class="feat-desc">Create, manage, and send approved WhatsApp Business templates for orders, appointments, and alerts.</div>
      </div>
      <div class="feat-card">
        <div class="feat-icon"><i class="fas fa-store"></i></div>
        <div class="feat-title">Product Catalog</div>
        <div class="feat-desc">Showcase your products directly inside WhatsApp. Customers browse, inquire, and order without leaving the chat.</div>
      </div>
      <div class="feat-card">
        <div class="feat-icon"><i class="fas fa-chart-bar"></i></div>
        <div class="feat-title">Analytics & Reports</div>
        <div class="feat-desc">Track message delivery, response times, agent performance, and bot effectiveness — all in real-time dashboards.</div>
      </div>
      <div class="feat-card">
        <div class="feat-icon"><i class="fas fa-user-shield"></i></div>
        <div class="feat-title">Roles & Permissions</div>
        <div class="feat-desc">Owner, manager, and agent roles with granular access control. Keep sensitive data secure as your team grows.</div>
      </div>
      <div class="feat-card">
        <div class="feat-icon"><i class="fas fa-phone"></i></div>
        <div class="feat-title">In-App Calling</div>
        <div class="feat-desc">Make and receive WhatsApp calls through the app without switching to your phone's WhatsApp. Full call logging included.</div>
      </div>
      <div class="feat-card">
        <div class="feat-icon"><i class="fas fa-shield-alt"></i></div>
        <div class="feat-title">Anti-Ban Protection</div>
        <div class="feat-desc">Smart rate limits, safe-send patterns, and message warmup built in — protect your WhatsApp Business number.</div>
      </div>
    </div>
  </div>
</section>

<!-- HOW IT WORKS -->
<section class="how-section" id="how">
  <div class="how-inner">
    <div class="fade-up" style="text-align:center">
      <div class="section-label">Simple setup</div>
      <h2>Up and Running in<br>Three Steps</h2>
      <p class="section-sub" style="margin:0 auto">No developers needed. If you can use WhatsApp, you can use Wabees.</p>
    </div>
    <div class="how-steps fade-up">
      <div class="how-step">
        <div class="step-num"><i class="step-icon fas fa-download"></i></div>
        <div class="step-title">Download & Install</div>
        <div class="step-desc">Get the Wabees Android app. Create your account in under a minute — just your phone number and email.</div>
      </div>
      <div class="how-step">
        <div class="step-num"><i class="step-icon fab fa-whatsapp"></i></div>
        <div class="step-title">Connect WhatsApp</div>
        <div class="step-desc">Link your WhatsApp Business API number. We guide you step by step — most users are connected in 15 minutes.</div>
      </div>
      <div class="how-step">
        <div class="step-num"><i class="step-icon fas fa-rocket"></i></div>
        <div class="step-title">Automate & Grow</div>
        <div class="step-desc">Set up your AI bot, add team members, and launch your first campaign. Watch response times drop to seconds.</div>
      </div>
    </div>
  </div>
</section>

<!-- AI SECTION -->
<section class="ai-section" id="ai">
  <div class="ai-inner">
    <div class="fade-up">
      <div class="section-label">DeepSeek-powered AI</div>
      <h2>Your AI That Actually<br>Understands Your Business</h2>
      <p class="section-sub">Train it on your FAQs, product catalogue, pricing, and business hours. It replies naturally in Urdu, English, and Roman Urdu — exactly like a real team member.</p>
      <div class="ai-features">
        <div class="ai-feat">
          <div class="ai-feat-icon"><i class="fas fa-brain"></i></div>
          <div class="ai-feat-text">
            <h4>Business-Specific Training</h4>
            <p>Upload your FAQs, prices, and policies. The AI only answers what you've taught it.</p>
          </div>
        </div>
        <div class="ai-feat">
          <div class="ai-feat-icon"><i class="fas fa-language"></i></div>
          <div class="ai-feat-text">
            <h4>Multi-Language Support</h4>
            <p>Responds in Urdu, English, Roman Urdu, or Punjabi — automatically matches the customer's language.</p>
          </div>
        </div>
        <div class="ai-feat">
          <div class="ai-feat-icon"><i class="fas fa-handshake"></i></div>
          <div class="ai-feat-text">
            <h4>Smart Human Handoff</h4>
            <p>Detects when a customer needs a human and instantly flags the conversation for your team.</p>
          </div>
        </div>
        <div class="ai-feat">
          <div class="ai-feat-icon"><i class="fas fa-clock"></i></div>
          <div class="ai-feat-text">
            <h4>Business Hours Awareness</h4>
            <p>Sends after-hours messages automatically and resumes AI replies when you open.</p>
          </div>
        </div>
      </div>
    </div>
    <div class="ai-visual fade-up">
      <div class="ai-terminal">
        <div class="terminal-header">
          <div class="dot-r"></div><div class="dot-y"></div><div class="dot-g"></div>
          <div class="terminal-title">AI Bot — Live Logs</div>
        </div>
        <div class="terminal-body">
          <div class="log-line">
            <span class="log-time">09:41</span>
            <span class="log-tag tag-msg">MSG</span>
            <span class="log-text">Incoming from <span class="hl">+92300…</span> "Price?"</span>
          </div>
          <div class="log-line">
            <span class="log-time">09:41</span>
            <span class="log-tag tag-bot">BOT</span>
            <span class="log-text">Trigger check — <span class="hl">allMessages</span> matched</span>
          </div>
          <div class="log-line">
            <span class="log-time">09:41</span>
            <span class="log-tag tag-ai">AI</span>
            <span class="log-text">Calling DeepSeek API (4 msgs context)</span>
          </div>
          <div class="log-line">
            <span class="log-time">09:41</span>
            <span class="log-tag tag-ok">OK</span>
            <span class="log-text">Reply sent in <span class="hl">1.4s</span> — 87 chars</span>
          </div>
          <div class="log-line">
            <span class="log-time">09:42</span>
            <span class="log-tag tag-msg">MSG</span>
            <span class="log-text">Incoming from <span class="hl">+92301…</span> "Order karna hai"</span>
          </div>
          <div class="log-line">
            <span class="log-time">09:42</span>
            <span class="log-tag tag-ai">AI</span>
            <span class="log-text">Language detected: <span class="hl">Urdu</span></span>
          </div>
          <div class="log-line">
            <span class="log-time">09:42</span>
            <span class="log-tag tag-ok">OK</span>
            <span class="log-text">Reply sent in <span class="hl">1.7s</span> — lead captured ✓</span>
          </div>
          <div class="log-line">
            <span class="log-time">09:43</span>
            <span class="log-tag tag-ai">AI</span>
            <span class="log-text">Waiting for next message<span class="cursor-blink"></span></span>
          </div>
        </div>
      </div>
    </div>
  </div>
</section>

<!-- PRICING -->
<section class="pricing-section" id="pricing">
  <div class="pricing-inner">
    <div class="pricing-header fade-up">
      <div class="section-label">Simple pricing</div>
      <h2>Start Free, Scale as You Grow</h2>
      <p class="section-sub" style="margin:0 auto">No contracts. No surprises. Cancel anytime.</p>
    </div>
    <div class="plans-grid fade-up">
      <!-- Starter -->
      <div class="plan-card">
        <div class="plan-name">Starter</div>
        <div class="plan-price"><sup>$</sup>0<span>/mo</span></div>
        <div class="plan-desc">Perfect for testing. Connect one WhatsApp number and explore the platform.</div>
        <ul class="plan-features">
          <li><i class="fas fa-check"></i> 1 WhatsApp number</li>
          <li><i class="fas fa-check"></i> 500 messages/month</li>
          <li><i class="fas fa-check"></i> Basic keyword bots</li>
          <li><i class="fas fa-check"></i> Web & mobile app</li>
          <li class="dimmed"><i class="fas fa-times"></i> AI bot</li>
          <li class="dimmed"><i class="fas fa-times"></i> Team agents</li>
          <li class="dimmed"><i class="fas fa-times"></i> Broadcast campaigns</li>
        </ul>
        <a href="<?= $downloadPath ?>" class="btn btn-ghost" style="width:100%;justify-content:center">Get Started Free</a>
      </div>
      <!-- Business -->
      <div class="plan-card popular">
        <div class="plan-popular-badge">⚡ Most Popular</div>
        <div class="plan-name">Business</div>
        <div class="plan-price"><sup>$</sup>29<span>/mo</span></div>
        <div class="plan-desc">For growing businesses that need AI automation and team collaboration.</div>
        <ul class="plan-features">
          <li><i class="fas fa-check"></i> 3 WhatsApp numbers</li>
          <li><i class="fas fa-check"></i> Unlimited messages</li>
          <li><i class="fas fa-check"></i> AI bot (300 replies/mo)</li>
          <li><i class="fas fa-check"></i> 5 team agents</li>
          <li><i class="fas fa-check"></i> Broadcast campaigns</li>
          <li><i class="fas fa-check"></i> Message templates</li>
          <li><i class="fas fa-check"></i> Analytics dashboard</li>
        </ul>
        <a href="<?= $webPortal ?>" class="btn btn-primary" style="width:100%;justify-content:center">Start 7-Day Trial</a>
      </div>
      <!-- Scale -->
      <div class="plan-card">
        <div class="plan-name">Scale</div>
        <div class="plan-price" style="font-size:2rem">Custom</div>
        <div class="plan-desc">For agencies and enterprises with high-volume needs and custom requirements.</div>
        <ul class="plan-features">
          <li><i class="fas fa-check"></i> Unlimited numbers</li>
          <li><i class="fas fa-check"></i> Unlimited messages</li>
          <li><i class="fas fa-check"></i> Unlimited AI replies</li>
          <li><i class="fas fa-check"></i> Unlimited agents</li>
          <li><i class="fas fa-check"></i> Dedicated support</li>
          <li><i class="fas fa-check"></i> Custom integrations</li>
          <li><i class="fas fa-check"></i> SLA guarantee</li>
        </ul>
        <a href="https://wa.me/923001234567?text=Hi%2C+I%27m+interested+in+the+Scale+plan" class="btn btn-ghost" style="width:100%;justify-content:center" target="_blank">Contact Sales</a>
      </div>
    </div>
  </div>
</section>

<!-- TESTIMONIALS -->
<section class="testimonials-section" id="testimonials">
  <div class="testimonials-inner">
    <div class="testimonials-header fade-up">
      <div class="section-label">Customer love</div>
      <h2>Businesses That Trust Wabees</h2>
    </div>
    <div class="testi-grid fade-up">
      <div class="testi-card">
        <div class="testi-stars">★★★★★</div>
        <div class="testi-text">"Our response time went from 2 hours to 8 seconds. The AI bot handles 70% of inquiries automatically. Sales doubled in 3 months."</div>
        <div class="testi-author">
          <div class="testi-avatar">A</div>
          <div>
            <div class="testi-name">Ahmed Raza</div>
            <div class="testi-biz">Online Electronics Store, Lahore</div>
          </div>
        </div>
      </div>
      <div class="testi-card">
        <div class="testi-stars">★★★★★</div>
        <div class="testi-text">"Managing 5 WhatsApp numbers for our salon chain was a nightmare. Wabees put everything in one app. Our team loves it."</div>
        <div class="testi-author">
          <div class="testi-avatar">F</div>
          <div>
            <div class="testi-name">Fatima Khan</div>
            <div class="testi-biz">Beauty Salon Chain, Karachi</div>
          </div>
        </div>
      </div>
      <div class="testi-card">
        <div class="testi-stars">★★★★★</div>
        <div class="testi-text">"The broadcast feature alone paid for the subscription 10x. We sent one campaign and got 40+ orders the same day."</div>
        <div class="testi-author">
          <div class="testi-avatar">U</div>
          <div>
            <div class="testi-name">Usman Ali</div>
            <div class="testi-biz">Clothing Brand, Islamabad</div>
          </div>
        </div>
      </div>
      <div class="testi-card">
        <div class="testi-stars">★★★★★</div>
        <div class="testi-text">"Setup mein sirf 20 minute lage. AI bot Urdu aur English dono mein perfect replies deta hai. Bilkul professional lagta hai."</div>
        <div class="testi-author">
          <div class="testi-avatar">S</div>
          <div>
            <div class="testi-name">Sara Malik</div>
            <div class="testi-biz">Real Estate Agency, Rawalpindi</div>
          </div>
        </div>
      </div>
      <div class="testi-card">
        <div class="testi-stars">★★★★★</div>
        <div class="testi-text">"The shared inbox is a game changer. My 3 agents all reply from one number and customers don't know the difference."</div>
        <div class="testi-author">
          <div class="testi-avatar">H</div>
          <div>
            <div class="testi-name">Hassan Tariq</div>
            <div class="testi-biz">Import/Export Business, Faisalabad</div>
          </div>
        </div>
      </div>
      <div class="testi-card">
        <div class="testi-stars">★★★★★</div>
        <div class="testi-text">"We manage 12 different business accounts for our agency clients. Wabees is the only platform that handles this at scale."</div>
        <div class="testi-author">
          <div class="testi-avatar">Z</div>
          <div>
            <div class="testi-name">Zainab Ahmed</div>
            <div class="testi-biz">Digital Marketing Agency, Multan</div>
          </div>
        </div>
      </div>
    </div>
  </div>
</section>

<!-- CTA -->
<section class="cta-section">
  <div class="cta-inner fade-up">
    <div class="section-label" style="justify-content:center">Start today</div>
    <h2>Ready to Automate<br>Your WhatsApp?</h2>
    <p>Download the app, connect your WhatsApp Business number, and watch your team's productivity multiply from day one.</p>
    <div class="cta-btns">
      <a href="<?= $downloadPath ?>" class="btn btn-primary btn-xl">
        <i class="fab fa-android"></i> Download Free App
      </a>
      <a href="<?= $webPortal ?>" class="btn btn-ghost btn-xl">
        <i class="fas fa-laptop"></i> Open Web Portal
      </a>
    </div>
    <div class="cta-secure">
      <div class="cta-secure-item"><i class="fas fa-lock"></i> End-to-end encrypted</div>
      <div class="cta-secure-item"><i class="fas fa-shield-alt"></i> GDPR compliant</div>
      <div class="cta-secure-item"><i class="fas fa-server"></i> 99.9% uptime SLA</div>
      <div class="cta-secure-item"><i class="fas fa-headset"></i> Support included</div>
    </div>
  </div>
</section>

<!-- FOOTER -->
<footer>
  <div class="footer-top">
    <div class="footer-brand">
      <a class="nav-logo" href="/" style="margin-bottom:0">
        <div class="nav-logo-icon"><i class="fab fa-whatsapp" style="color:#fff"></i></div>
        <span class="nav-logo-text">Wabees</span>
      </a>
      <p>The all-in-one WhatsApp Business Automation Platform. Built for Pakistani businesses, powered by AI.</p>
    </div>
    <div class="footer-col">
      <h4>Product</h4>
      <ul>
        <li><a href="#features">Features</a></li>
        <li><a href="#pricing">Pricing</a></li>
        <li><a href="#ai">AI Bot</a></li>
        <li><a href="<?= $downloadPath ?>">Download App</a></li>
      </ul>
    </div>
    <div class="footer-col">
      <h4>Platform</h4>
      <ul>
        <li><a href="<?= $webPortal ?>">Web Portal</a></li>
        <li><a href="<?= $downloadPath ?>">Android App</a></li>
        <li><a href="<?= $domain ?>/download/about.php">About</a></li>
        <li><a href="<?= $domain ?>/download/contact.php">Contact</a></li>
      </ul>
    </div>
    <div class="footer-col">
      <h4>Legal</h4>
      <ul>
        <li><a href="<?= $domain ?>/privacy.php">Privacy Policy</a></li>
        <li><a href="<?= $domain ?>/terms.php">Terms of Service</a></li>
        <li><a href="<?= $domain ?>/download/data-deletion.php">Data Deletion</a></li>
      </ul>
    </div>
  </div>
  <div class="footer-bottom">
    <div class="footer-copy">© <?= date('Y') ?> Wabees. All rights reserved. Made with ❤️ in Pakistan.</div>
    <div class="footer-badges">
      <div class="footer-badge"><i class="fab fa-whatsapp"></i> WhatsApp Business API</div>
      <div class="footer-badge"><i class="fas fa-shield-alt"></i> Secure & Compliant</div>
    </div>
  </div>
</footer>

<!-- WhatsApp FAB -->
<a href="https://wa.me/923001234567" class="wa-fab" target="_blank" title="Chat on WhatsApp">
  <i class="fab fa-whatsapp"></i>
</a>

<script>
// ── SCROLL FADE-UP ──
const observer = new IntersectionObserver((entries) => {
  entries.forEach(e => {
    if(e.isIntersecting) { e.target.classList.add('visible'); }
  });
}, { threshold: 0.1, rootMargin: '0px 0px -50px 0px' });
document.querySelectorAll('.fade-up').forEach(el => observer.observe(el));

// ── LIVE STATS ──
function fmtNum(n) {
  if(n >= 1000000) return (n/1000000).toFixed(1).replace('.0','') + 'M';
  if(n >= 1000) return (n/1000).toFixed(1).replace('.0','') + 'K';
  return n.toString();
}

async function loadStats() {
  try {
    const r = await fetch('/stats.php', { cache: 'no-store' });
    const d = await r.json();
    const map = {
      'msgs': d.messages,
      'users': d.users,
      'agents': d.agents,
      'contacts': d.contacts,
      'bots': d.bots,
      'convs': d.conversations,
    };
    for(const [k, v] of Object.entries(map)) {
      const el = document.getElementById('s-' + k);
      if(el) el.textContent = fmtNum(v || 0);
    }
  } catch(e) {
    // silent
  }
}
loadStats();
setInterval(loadStats, 30000);

// ── NAV SCROLL EFFECT ──
const nav = document.querySelector('nav');
window.addEventListener('scroll', () => {
  if(window.scrollY > 40) {
    nav.style.background = 'rgba(8,13,20,.95)';
    nav.style.borderBottomColor = 'rgba(255,255,255,.1)';
  } else {
    nav.style.background = 'rgba(8,13,20,.8)';
    nav.style.borderBottomColor = 'rgba(255,255,255,.08)';
  }
}, { passive: true });
</script>
</body>
</html>
