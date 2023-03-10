package org.skillsmapper.factservice;

import java.time.LocalDateTime;
import java.util.Objects;

import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "Facts")
public class Fact {

    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private Long id;

    private LocalDateTime timestamp;

    private String userUID;

    private String level;

    private String skill;

    protected Fact() {
    }

    public Fact(String userUID, String level, String skill) {
        this.userUID = userUID;
        this.timestamp = LocalDateTime.now();
        this.level = level;
        this.skill = skill;
    }

    public Long getId() {
        return id;
    }

    public String getLevel() {
        return level;
    }

    public String getSkill() {
        return skill;
    }

    public String getUserUID() {
        return userUID;
    }

    public LocalDateTime getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(final LocalDateTime timestamp) {
        this.timestamp = timestamp;
    }

    @Override
    public String toString() {
        return "Fact{" +
                "id=" + id +
                ", timestamp=" + timestamp +
                ", userUID='" + userUID + '\'' +
                ", level='" + level + '\'' +
                ", skill='" + skill + '\'' +
                '}';
    }

    @Override
    public boolean equals(final Object o) {
        if (this == o) {
            return true;
        }
        if (o == null || getClass() != o.getClass()) {
            return false;
        }
        final Fact fact = (Fact) o;
        return Objects.equals(id, fact.id) && Objects.equals(timestamp, fact.timestamp) && Objects.equals(userUID, fact.userUID) && Objects.equals(level,
                fact.level) && Objects.equals(skill, fact.skill);
    }

    @Override
    public int hashCode() {
        return Objects.hash(id, timestamp, userUID, level, skill);
    }

    public void setUserUID(final String person) {
        this.userUID = person;
    }

    public void setSkill(final String skill) {
        this.skill = skill;
    }

    public void setLevel(final String type) {
        this.level = type;
    }

    public void setId(final Long id) {
        this.id = id;
    }
}
