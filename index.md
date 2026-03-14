---
layout: default
title: Home
---

<div class="home-hero">
  <h1>Claude Code Hub</h1>
  <p class="hero-subtitle">패치노트, 리소스, 팁을 한곳에서 확인하세요</p>
</div>

<div class="home-section">
  <h2>📋 Latest Patch Notes</h2>
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
  <h2>🚀 Quick Links</h2>
  <div class="quick-links">
    <a href="{{ '/pages/resources/getting-started' | relative_url }}" class="quick-link-card">
      <span class="card-icon">📚</span>
      <span class="card-title">Getting Started</span>
      <span class="card-desc">Claude Code 시작 가이드</span>
    </a>
    <a href="{{ '/pages/cheatsheet/commands' | relative_url }}" class="quick-link-card">
      <span class="card-icon">⌨️</span>
      <span class="card-title">Commands</span>
      <span class="card-desc">CLI 명령어 정리</span>
    </a>
    <a href="{{ '/pages/tips/productivity' | relative_url }}" class="quick-link-card">
      <span class="card-icon">💡</span>
      <span class="card-title">Tips & Tricks</span>
      <span class="card-desc">생산성을 높이는 팁</span>
    </a>
    <a href="{{ '/pages/cheatsheet/shortcuts' | relative_url }}" class="quick-link-card">
      <span class="card-icon">🔑</span>
      <span class="card-title">Shortcuts</span>
      <span class="card-desc">단축키 모음</span>
    </a>
  </div>
</div>
