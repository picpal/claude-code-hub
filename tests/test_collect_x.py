def test_read_creators_picks_x_handle_column(tmp_path, monkeypatch):
    import collect_x

    f = tmp_path / "creators.tsv"
    f.write_text(
        "# name\tyoutube_channel_id\tx_handle\n"
        "Andrej Karpathy\tUC1\tkarpathy\n"
        "No X Person\tUC2\t\n"
        "X Only\t\tsimonw\n"
    )
    monkeypatch.setattr(collect_x, "CREATORS", f)
    assert collect_x.read_creators() == [("Andrej Karpathy", "karpathy"), ("X Only", "simonw")]
