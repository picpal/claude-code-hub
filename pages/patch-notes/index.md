---
layout: list
title: Patch Notes
description: Claude Code의 모든 릴리즈 노트를 확인하세요.
permalink: /pages/patch-notes/
---

<ul class="patch-list">
  {% assign notes = site.pages | where_exp: "p", "p.url contains '/pages/patch-notes/'" | where_exp: "p", "p.url != '/pages/patch-notes/'" | sort: "date" | reverse %}
  {% for note in notes %}
  <li>
    <a href="{{ note.url | relative_url }}">
      <span class="patch-version">{{ note.title }}</span>
      <span class="patch-date">{{ note.date | date: "%Y-%m-%d" }}</span>
    </a>
  </li>
  {% endfor %}
</ul>
