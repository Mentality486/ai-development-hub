package com.aihub.common;

import java.util.List;

/** 简单分页结果。 */
public class Pagination<T> {

    private List<T> records;
    private long total;
    private int page;
    private int size;

    public Pagination() {
    }

    public Pagination(List<T> records, long total, int page, int size) {
        this.records = records;
        this.total = total;
        this.page = page;
        this.size = size;
    }

    public List<T> getRecords() {
        return records;
    }

    public long getTotal() {
        return total;
    }

    public int getPage() {
        return page;
    }

    public int getSize() {
        return size;
    }
}
