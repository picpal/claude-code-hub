---
layout: default
title: Home
---

<div class="home-hero">
  <h1>Claude Code Hub</h1>
  <p class="hero-subtitle">패치노트, 리소스, 팁을 한곳에서 확인하세요</p>
</div>

<div class="home-section">
  <h2>Latest Patch Notes</h2>
  <ul class="patch-list">
    {% assign notes = site.pages | where_exp: "p", "p.url contains '/pages/patch-notes/'" | where_exp: "p", "p.url != '/pages/patch-notes/'" | sort: "date" | reverse %}
    {% for note in notes limit:5 %}
    <li>
      <a href="{{ note.url | relative_url }}">
        <span class="patch-version">{{ note.title }}</span>
        <span class="patch-date">{{ note.date | date: "%Y-%m-%d" }}</span>
      </a>
    </li>
    {% endfor %}
  </ul>
</div>

<div class="home-section">
  <h2>Quick Links</h2>
  <div class="quick-links">
    <a href="{{ '/pages/resources/getting-started/' | relative_url }}" class="quick-link-card">
      <span class="card-icon"><svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg></span>
      <span class="card-title">Getting Started</span>
      <span class="card-desc">Claude Code 시작 가이드</span>
    </a>
    <a href="{{ '/pages/cheatsheet/commands/' | relative_url }}" class="quick-link-card">
      <span class="card-icon"><svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="4 17 10 11 4 5"/><line x1="12" y1="19" x2="20" y2="19"/></svg></span>
      <span class="card-title">Commands</span>
      <span class="card-desc">CLI 명령어 정리</span>
    </a>
    <a href="{{ '/pages/tips/productivity/' | relative_url }}" class="quick-link-card">
      <span class="card-icon"><svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="9" y1="18" x2="15" y2="18"/><line x1="10" y1="22" x2="14" y2="22"/><path d="M15.09 14c.18-.98.65-1.74 1.41-2.5A4.65 4.65 0 0 0 18 8 6 6 0 0 0 6 8c0 1 .23 2.23 1.5 3.5A4.61 4.61 0 0 1 8.91 14"/></svg></span>
      <span class="card-title">Tips & Tricks</span>
      <span class="card-desc">생산성을 높이는 팁</span>
    </a>
    <a href="{{ '/pages/cheatsheet/shortcuts/' | relative_url }}" class="quick-link-card">
      <span class="card-icon"><svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m21 2-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0 3 3L22 7l-3-3m-3.5 3.5L19 4"/></svg></span>
      <span class="card-title">Shortcuts</span>
      <span class="card-desc">단축키 모음</span>
    </a>
  </div>
</div>
